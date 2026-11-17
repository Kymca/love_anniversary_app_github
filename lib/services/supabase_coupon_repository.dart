import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coupon.dart';
import 'coupon_repository.dart';
import 'pair_repository.dart';

class SupabaseCouponRepository implements PairCouponRepository {
  SupabaseCouponRepository({
    required this.client,
    required this.pairRepository,
    required this.fallback,
  });

  final SupabaseClient client;
  final PairRepository pairRepository;
  final CouponRepository fallback;

  Future<String?> _activePairId() async =>
      (await pairRepository.loadActivePair())?.id;

  @override
  Future<List<Coupon>> load({DateTime? now}) async {
    final date = now ?? DateTime.now();
    final pairId = await _activePairId();
    if (pairId == null) return fallback.load(now: date);
    final rows = await client
        .from('pair_coupon_states')
        .select(
          'coupon_id, coupon_type, period_key, last_activated_at, activated_by, updated_at',
        )
        .eq('pair_id', pairId);
    final states = <String, _CouponState>{
      for (final row in rows)
        row['coupon_id'] as String: _stateFromRow(row),
    };
    final coupons = [
      for (final coupon in defaultCoupons)
        _applyState(coupon, states[coupon.id], date),
      _applyState(dailyCouponFor(date), states[dailyCouponFor(date).id], date),
    ];
    return List.unmodifiable(coupons);
  }

  @override
  Future<bool> activate(String id, {DateTime? at}) async {
    final activationTime = at ?? DateTime.now();
    final pairId = await _activePairId();
    if (pairId == null) return fallback.activate(id, at: activationTime);
    final coupon = (await load(now: activationTime)).where(
      (item) => item.id == id,
    );
    if (coupon.isEmpty || !coupon.first.isEligibleAt(activationTime)) {
      return false;
    }
    final response = await client.rpc(
      'activate_pair_coupon',
      params: {
        'p_pair_id': pairId,
        'p_coupon_id': id,
        'p_coupon_type': coupon.first.type.name,
        'p_period_key': coupon.first.type == CouponType.monthly
            ? _monthKey(activationTime)
            : null,
      },
    );
    if (response is! bool) {
      throw const FormatException(
        'Backend returned an invalid coupon activation result.',
      );
    }
    return response;
  }

  @override
  Stream<void> watchChanges() async* {
    final pairId = await _activePairId();
    if (pairId == null) return;
    yield* client
        .from('pair_coupon_states')
        .stream(primaryKey: ['pair_id', 'coupon_id'])
        .eq('pair_id', pairId)
        .map((_) {});
  }

  @override
  Stream<Coupon> watchPartnerActivations() async* {
    final pairId = await _activePairId();
    final userId = client.auth.currentUser?.id;
    if (pairId == null || userId == null) return;

    var isInitialSnapshot = true;
    final seenUpdates = <String, String>{};
    await for (final rows
        in client
            .from('pair_coupon_states')
            .stream(primaryKey: ['pair_id', 'coupon_id'])
            .eq('pair_id', pairId)) {
      final events = <Coupon>[];
      for (final row in rows) {
        final state = _stateFromRow(row);
        final previousUpdate = seenUpdates[state.id];
        seenUpdates[state.id] = state.updatedAt;
        if (isInitialSnapshot ||
            previousUpdate == state.updatedAt ||
            state.activatedBy == userId) {
          continue;
        }
        final coupon = _couponForId(state.id, DateTime.now());
        if (coupon != null) {
          events.add(
            coupon.copyWith(
              isActivated: true,
              lastActivatedAt: DateTime.parse(state.lastActivatedAt).toLocal(),
            ),
          );
        }
      }
      isInitialSnapshot = false;
      for (final coupon in events) {
        yield coupon;
      }
    }
  }

  Coupon _applyState(Coupon coupon, _CouponState? state, DateTime now) {
    if (state == null) return coupon;
    if (state.type != coupon.type.name) {
      throw FormatException('Coupon type mismatch for ${coupon.id}.');
    }
    final activationDate = DateTime.parse(state.lastActivatedAt).toLocal();
    final active = switch (coupon.type) {
      CouponType.oneTime || CouponType.daily => true,
      CouponType.monthly => state.periodKey == _monthKey(now),
    };
    return coupon.copyWith(
      isActivated: active,
      lastActivatedAt: activationDate,
    );
  }

  _CouponState _stateFromRow(Map<String, dynamic> row) {
    final id = row['coupon_id'];
    final type = row['coupon_type'];
    final periodKey = row['period_key'];
    final activatedAt = row['last_activated_at'];
    final activatedBy = row['activated_by'];
    final updatedAt = row['updated_at'];
    if (id is! String ||
        type is! String ||
        (periodKey != null && periodKey is! String) ||
        activatedAt is! String ||
        activatedBy is! String ||
        updatedAt is! String) {
      throw const FormatException('Backend returned invalid coupon state.');
    }
    return _CouponState(
      id: id,
      type: type,
      periodKey: periodKey as String?,
      lastActivatedAt: activatedAt,
      activatedBy: activatedBy,
      updatedAt: updatedAt,
    );
  }

  Coupon? _couponForId(String id, DateTime date) {
    for (final coupon in defaultCoupons) {
      if (coupon.id == id) return coupon;
    }
    final daily = dailyCouponFor(date);
    return daily.id == id ? daily : null;
  }
}

class _CouponState {
  const _CouponState({
    required this.id,
    required this.type,
    required this.periodKey,
    required this.lastActivatedAt,
    required this.activatedBy,
    required this.updatedAt,
  });

  final String id;
  final String type;
  final String? periodKey;
  final String lastActivatedAt;
  final String activatedBy;
  final String updatedAt;
}

String _monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}';
