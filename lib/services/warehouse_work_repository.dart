import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'grocery_wallet.dart';
import 'duck_ownership_repository.dart';

class WarehouseWorkRepository {
  WarehouseWorkRepository({
    this.preferences,
    DateTime Function()? clock,
    DuckOwnershipService? ownershipRepository,
  }) : _clock = clock ?? DateTime.now,
       _ownershipRepository =
           ownershipRepository ??
           DuckOwnershipRepository(preferences: preferences);

  static const storageKey = 'tamagotchi_warehouse_work';
  static const cooldown = Duration(hours: 3);
  static const totalBoxes = 15;

  final SharedPreferences? preferences;
  final DateTime Function() _clock;
  final DuckOwnershipService _ownershipRepository;
  Future<void> _mutationTail = Future<void>.value();

  Future<SharedPreferences> get _store async =>
      preferences ?? await SharedPreferences.getInstance();

  Future<WarehouseWorkState> load() async {
    final stored = (await _store).getString(storageKey);
    if (stored == null) return const WarehouseWorkState();

    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid warehouse work data');
    }

    final state = WarehouseWorkState.fromJson(decoded);
    final completionIsPartial =
        state.completedRunId != null &&
        (state.completedCaught == null ||
            state.completedMissed == null ||
            state.completedReward == null);
    if (state.caught < 0 ||
        state.missed < 0 ||
        state.caught + state.missed > totalBoxes ||
        state.completedCaught != null &&
            state.completedMissed != null &&
            state.completedCaught! + state.completedMissed! != totalBoxes ||
        completionIsPartial ||
        state.completedRunId == null &&
            (state.completedCaught != null ||
                state.completedMissed != null ||
                state.completedReward != null) ||
        state.activeRunId != null &&
            (state.caught + state.missed >= totalBoxes ||
                state.completedRunId != null)) {
      throw const FormatException('Invalid warehouse work progress');
    }
    return state;
  }

  Future<WarehouseWorkState> beginWork() => _serialize(() async {
    final state = await load();
    if (state.activeRunId != null) {
      await _ownershipRepository.requireParticipantSide(
        state.ownerSide ?? 'first',
      );
      return state;
    }
    final now = _clock();
    final ownerSide = await _ownershipRepository.requireCurrentOwner(now);
    final availableAt = (state.lastCompletedAt ?? state.lastStartedAt)?.add(
      cooldown,
    );
    if (availableAt != null && now.isBefore(availableAt)) {
      throw WarehouseCooldownException(availableAt.difference(now));
    }

    final runId = now.microsecondsSinceEpoch.toString();
    final nextState = state.copyWith(
      lastStartedAt: now,
      activeRunId: runId,
      ownerSide: ownerSide,
      caught: 0,
      missed: 0,
      clearCompletion: true,
    );
    await _save(nextState);
    return nextState;
  });

  Future<void> saveProgress(
    String runId, {
    required int caught,
    required int missed,
  }) {
    if (caught < 0 || missed < 0 || caught + missed >= totalBoxes) {
      throw ArgumentError('Invalid warehouse work progress');
    }
    return _serialize(() async {
      final state = await load();
      if (state.activeRunId != runId) {
        throw StateError('Warehouse work session is no longer active');
      }
      await _ownershipRepository.requireParticipantSide(
        state.ownerSide ?? 'first',
      );
      if (caught < state.caught || missed < state.missed) {
        throw StateError('Warehouse work progress cannot move backwards');
      }
      await _save(state.copyWith(caught: caught, missed: missed));
    });
  }

  Future<WarehouseWorkState> completeWork(
    String runId, {
    required int caught,
    required int missed,
    required GroceryWallet wallet,
  }) => _serialize(() async {
    final state = await load();
    if (state.completedRunId == runId) {
      await _ownershipRepository.requireParticipantSide(
        state.ownerSide ?? 'first',
      );
      await _recoverPendingReward(state, wallet);
      return load();
    }
    if (state.activeRunId != runId) {
      throw StateError('Warehouse work session is no longer active');
    }
    await _ownershipRepository.requireParticipantSide(
      state.ownerSide ?? 'first',
    );
    if (caught < 0 ||
        missed < 0 ||
        caught + missed != totalBoxes ||
        caught < state.caught ||
        missed < state.missed) {
      throw StateError('Warehouse work is not complete');
    }

    final reward = warehouseRewardFor(caught);
    final completed = state.copyWith(
      clearActiveRun: true,
      caught: caught,
      missed: missed,
      lastCompletedAt: _clock(),
      completedRunId: runId,
      completedCaught: caught,
      completedMissed: missed,
      completedReward: reward,
      rewardGranted: false,
    );
    await _save(completed);
    await _recoverPendingReward(completed, wallet);
    return load();
  });

  Future<void> recoverPendingReward(
    WarehouseWorkState state,
    GroceryWallet wallet,
  ) => _serialize(() => _recoverPendingReward(state, wallet));

  Future<void> _recoverPendingReward(
    WarehouseWorkState state,
    GroceryWallet wallet,
  ) async {
    final runId = state.completedRunId;
    if (runId == null) return;
    final current = await load();
    if (current.completedRunId != runId || current.rewardGranted) return;
    await wallet.grantOnce('warehouse:$runId', current.completedReward!);
    await _save(current.copyWith(rewardGranted: true));
  }

  DateTime? nextAvailableAt(WarehouseWorkState state) =>
      (state.lastCompletedAt ?? state.lastStartedAt)?.add(cooldown);

  Future<void> _save(WarehouseWorkState state) async {
    final saved = await (await _store).setString(
      storageKey,
      jsonEncode(state.toJson()),
    );
    if (!saved) throw StateError('Could not save warehouse work');
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final previous = _mutationTail;
    final result = Completer<T>();
    _mutationTail = result.future.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    previous.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}

int warehouseRewardFor(int caught) {
  if (caught < 0 || caught > WarehouseWorkRepository.totalBoxes) {
    throw ArgumentError.value(caught, 'caught');
  }
  if (caught == WarehouseWorkRepository.totalBoxes) return 500;
  if (caught > WarehouseWorkRepository.totalBoxes ~/ 2) return 250;
  return 0;
}

class WarehouseCooldownException implements Exception {
  const WarehouseCooldownException(this.remaining);

  final Duration remaining;
}

class WarehouseWorkState {
  const WarehouseWorkState({
    this.lastStartedAt,
    this.lastCompletedAt,
    this.activeRunId,
    this.ownerSide,
    this.caught = 0,
    this.missed = 0,
    this.completedRunId,
    this.completedCaught,
    this.completedMissed,
    this.completedReward,
    this.rewardGranted = true,
  });

  final DateTime? lastStartedAt;
  final DateTime? lastCompletedAt;
  final String? activeRunId;
  final String? ownerSide;
  final int caught;
  final int missed;
  final String? completedRunId;
  final int? completedCaught;
  final int? completedMissed;
  final int? completedReward;
  final bool rewardGranted;

  bool get hasCompletion => completedRunId != null;

  WarehouseWorkState copyWith({
    DateTime? lastStartedAt,
    DateTime? lastCompletedAt,
    String? activeRunId,
    String? ownerSide,
    int? caught,
    int? missed,
    String? completedRunId,
    int? completedCaught,
    int? completedMissed,
    int? completedReward,
    bool? rewardGranted,
    bool clearActiveRun = false,
    bool clearCompletion = false,
  }) => WarehouseWorkState(
    lastStartedAt: lastStartedAt ?? this.lastStartedAt,
    lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
    activeRunId: clearActiveRun ? null : activeRunId ?? this.activeRunId,
    ownerSide: clearActiveRun ? null : ownerSide ?? this.ownerSide,
    caught: caught ?? this.caught,
    missed: missed ?? this.missed,
    completedRunId: clearCompletion
        ? null
        : completedRunId ?? this.completedRunId,
    completedCaught: clearCompletion
        ? null
        : completedCaught ?? this.completedCaught,
    completedMissed: clearCompletion
        ? null
        : completedMissed ?? this.completedMissed,
    completedReward: clearCompletion
        ? null
        : completedReward ?? this.completedReward,
    rewardGranted: clearCompletion ? true : rewardGranted ?? this.rewardGranted,
  );

  Map<String, Object?> toJson() => {
    'lastStartedAt': lastStartedAt?.toIso8601String(),
    'lastCompletedAt': lastCompletedAt?.toIso8601String(),
    'activeRunId': activeRunId,
    'ownerSide': ownerSide,
    'caught': caught,
    'missed': missed,
    'completedRunId': completedRunId,
    'completedCaught': completedCaught,
    'completedMissed': completedMissed,
    'completedReward': completedReward,
    'rewardGranted': rewardGranted,
  };

  factory WarehouseWorkState.fromJson(Map<String, dynamic> json) {
    DateTime? readDate(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) {
        throw const FormatException('Invalid warehouse date');
      }
      return DateTime.tryParse(value) ??
          (throw const FormatException('Invalid warehouse date'));
    }

    int readCount(String key, {int fallback = 0}) {
      final value = json[key] ?? fallback;
      if (value is! int) throw const FormatException('Invalid warehouse count');
      return value;
    }

    String? readString(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) throw const FormatException('Invalid warehouse id');
      return value;
    }

    String? readSide() {
      final value = json['ownerSide'];
      if (value == null) return null;
      if (value != 'first' && value != 'second') {
        throw const FormatException('Invalid warehouse owner side');
      }
      return value as String;
    }

    final rewardGranted = json['rewardGranted'] ?? true;
    if (rewardGranted is! bool) {
      throw const FormatException('Invalid warehouse reward state');
    }
    return WarehouseWorkState(
      lastStartedAt: readDate('lastStartedAt'),
      lastCompletedAt: readDate('lastCompletedAt'),
      activeRunId: readString('activeRunId'),
      ownerSide: readSide(),
      caught: readCount('caught'),
      missed: readCount('missed'),
      completedRunId: readString('completedRunId'),
      completedCaught: json['completedCaught'] == null
          ? null
          : readCount('completedCaught'),
      completedMissed: json['completedMissed'] == null
          ? null
          : readCount('completedMissed'),
      completedReward: json['completedReward'] == null
          ? null
          : readCount('completedReward'),
      rewardGranted: rewardGranted,
    );
  }
}
