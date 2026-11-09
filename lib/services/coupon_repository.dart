import 'package:hive_flutter/hive_flutter.dart';

import '../models/coupon.dart';

abstract interface class CouponRepository {
  Future<List<Coupon>> load({DateTime? now});

  Future<bool> activate(String id, {DateTime? at});
}

class HiveCouponRepository implements CouponRepository {
  HiveCouponRepository(this._box);

  static const boxName = 'wish_coupons';
  static Future<HiveCouponRepository>? _openFuture;

  final Box<Coupon> _box;
  final Set<String> _activatingIds = {};

  static Future<HiveCouponRepository> open({bool seedDefaults = true}) {
    final existing = _openFuture;
    if (existing != null) return existing;
    final future = _open(seedDefaults: seedDefaults);
    _openFuture = future;
    return future.catchError((Object error, StackTrace stackTrace) {
      _openFuture = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  static Future<HiveCouponRepository> _open({
    required bool seedDefaults,
  }) async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(CouponAdapter.adapterTypeId)) {
      Hive.registerAdapter(CouponAdapter());
    }
    final repository = HiveCouponRepository(
      await Hive.openBox<Coupon>(boxName),
    );
    if (seedDefaults && repository._box.isEmpty) {
      await repository._box.putAll({
        for (final coupon in defaultCoupons) coupon.id: coupon,
      });
    }
    return repository;
  }

  @override
  Future<List<Coupon>> load({DateTime? now}) async {
    final date = now ?? DateTime.now();
    final coupons = _box.values.toList(growable: false);
    for (final coupon in coupons) {
      final lastActivation = coupon.lastActivatedAt;
      if (coupon.type == CouponType.monthly &&
          coupon.isActivated &&
          (lastActivation == null || !_sameMonth(lastActivation, date))) {
        await _box.put(coupon.id, coupon.copyWith(isActivated: false));
      }
    }
    final daily = _dailyCouponFor(date);
    if (!_box.containsKey(daily.id)) await _box.put(daily.id, daily);
    return List.unmodifiable(_box.values);
  }

  @override
  Future<bool> activate(String id, {DateTime? at}) async {
    if (!_activatingIds.add(id)) return false;
    try {
      final coupon = _box.get(id);
      if (coupon == null) return false;
      final activationDate = at ?? DateTime.now();
      if (!coupon.isEligibleAt(activationDate)) return false;
      await _box.put(
        id,
        coupon.copyWith(isActivated: true, lastActivatedAt: activationDate),
      );
      return true;
    } finally {
      _activatingIds.remove(id);
    }
  }

  static bool _sameMonth(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month;
}

class InMemoryCouponRepository implements CouponRepository {
  InMemoryCouponRepository([List<Coupon> coupons = const []])
    : _coupons = {for (final coupon in coupons) coupon.id: coupon};

  final Map<String, Coupon> _coupons;
  final Set<String> _activatingIds = {};

  @override
  Future<List<Coupon>> load({DateTime? now}) async {
    final date = now ?? DateTime.now();
    for (final coupon in _coupons.values.toList(growable: false)) {
      final lastActivation = coupon.lastActivatedAt;
      if (coupon.type == CouponType.monthly &&
          coupon.isActivated &&
          (lastActivation == null ||
              lastActivation.year != date.year ||
              lastActivation.month != date.month)) {
        _coupons[coupon.id] = coupon.copyWith(isActivated: false);
      }
    }
    final daily = _dailyCouponFor(date);
    _coupons.putIfAbsent(daily.id, () => daily);
    return List.unmodifiable(_coupons.values);
  }

  @override
  Future<bool> activate(String id, {DateTime? at}) async {
    if (!_activatingIds.add(id)) return false;
    try {
      final coupon = _coupons[id];
      final activationDate = at ?? DateTime.now();
      if (coupon == null || !coupon.isEligibleAt(activationDate)) {
        return false;
      }
      _coupons[id] = coupon.copyWith(
        isActivated: true,
        lastActivatedAt: activationDate,
      );
      return true;
    } finally {
      _activatingIds.remove(id);
    }
  }
}

Coupon _dailyCouponFor(DateTime date) {
  final day =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return Coupon(
    id: 'daily-$day',
    title: 'Маленькое желание дня',
    description: 'Выбери приятный сюрприз для нас сегодня.',
    icon: 'favorite',
    type: CouponType.daily,
  );
}

const defaultCoupons = <Coupon>[
  Coupon(
    id: 'breakfast',
    title: 'Завтрак в постель',
    description: 'Вкусное утро, приготовленное с любовью.',
    icon: 'restaurant',
    type: CouponType.monthly,
  ),
  Coupon(
    id: 'movie-night',
    title: 'Вечер кино',
    description: 'Ты выбираешь фильм, а я готовлю вкусняшки.',
    icon: 'movie',
    type: CouponType.monthly,
  ),
  Coupon(
    id: 'massage',
    title: 'Массаж',
    description: 'Полчаса нежности и отдыха только для тебя.',
    icon: 'spa',
    type: CouponType.oneTime,
  ),
  Coupon(
    id: 'date-night',
    title: 'Свидание-сюрприз',
    description: 'Один особенный вечер, который я организую сам.',
    icon: 'celebration',
    type: CouponType.oneTime,
  ),
];
