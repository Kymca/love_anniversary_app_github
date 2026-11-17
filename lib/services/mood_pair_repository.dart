import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_mood.dart';
import 'participant_profile_repository.dart';

class DailyPairMood {
  const DailyPairMood({required this.dateKey, required this.moods});

  final String dateKey;
  final Map<String, DailyMood> moods;

  String get reaction {
    final first = moods['first'];
    final second = moods['second'];
    if (first == null || second == null) {
      return 'Ждём настроение второго участника.';
    }
    if (first == DailyMood.blue && second == DailyMood.blue) {
      return 'Утка укутывает вас пледом и приносит чай. Можно просто поддержать друг друга.';
    }
    if (first == DailyMood.joyful && second == DailyMood.joyful) {
      return 'Утка приглашает вас на маленький праздничный танец!';
    }
    return 'Утка напоминает: сегодня можно спросить друг друга, какая поддержка будет приятна.';
  }
}

abstract interface class MoodPairRepository {
  bool get isSynchronized;

  Future<DailyPairMood> loadFor(DateTime date);
  Future<List<DailyMoodEntry>> historyFor(String participant, DateTime date);
  Future<List<DailyMoodEntry>> historyForParticipant(String participant);
  Stream<void> watchChanges();
  Stream<DailyPairMood> watchFor(DateTime date);

  Future<DailyPairMood> record(
    String participant,
    DailyMood mood, {
    required DateTime date,
  });
}

class SharedPreferencesMoodPairRepository implements MoodPairRepository {
  SharedPreferencesMoodPairRepository({
    this.preferences,
    ParticipantProfileRepository? profileRepository,
  }) : _profileRepository =
           profileRepository ??
           ParticipantProfileRepository(preferences: preferences);

  static const storageKey = 'same_device_pair_moods_v1';
  final SharedPreferences? preferences;
  final ParticipantProfileRepository _profileRepository;

  @override
  bool get isSynchronized => false;

  @override
  Stream<DailyPairMood> watchFor(DateTime date) => const Stream.empty();

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  Future<DailyPairMood> loadFor(DateTime date) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final all = _decode(prefs.getString(storageKey));
    final key = moodDateKey(date);
    final raw = all[key];
    if (raw is! Map<String, dynamic>) {
      return DailyPairMood(dateKey: key, moods: const {});
    }
    final normalized = _normalizeDay(raw, dateKey: key);
    if (normalized.changed) {
      all[key] = normalized.value;
      await prefs.setString(storageKey, jsonEncode(all));
    }
    return DailyPairMood(
      dateKey: key,
      moods: {
        for (final side in const ['first', 'second'])
          if (normalized.histories[side]?.isNotEmpty ?? false)
            side: normalized.histories[side]!.last.mood,
      },
    );
  }

  @override
  Future<List<DailyMoodEntry>> historyFor(
    String participant,
    DateTime date,
  ) async {
    _validateSide(participant);
    final all = _decode(
      (preferences ?? await SharedPreferences.getInstance()).getString(
        storageKey,
      ),
    );
    final raw = all[moodDateKey(date)];
    if (raw is! Map<String, dynamic>) return const [];
    final normalized = _normalizeDay(raw, dateKey: moodDateKey(date));
    final history = normalized.histories[participant] ?? const [];
    return List.unmodifiable(history);
  }

  @override
  Future<List<DailyMoodEntry>> historyForParticipant(String participant) async {
    _validateSide(participant);
    final all = _decode(
      (preferences ?? await SharedPreferences.getInstance()).getString(
        storageKey,
      ),
    );
    final entries = <DailyMoodEntry>[];
    for (final dateEntry in all.entries) {
      if (DateTime.tryParse(dateEntry.key) == null ||
          dateEntry.value is! Map<String, dynamic>) {
        continue;
      }
      entries.addAll(
        _normalizeDay(
              dateEntry.value as Map<String, dynamic>,
              dateKey: dateEntry.key,
            ).histories[participant] ??
            const [],
      );
    }
    entries.sort(_compareEntries);
    return List.unmodifiable(entries);
  }

  @override
  Future<DailyPairMood> record(
    String participant,
    DailyMood mood, {
    required DateTime date,
  }) async {
    _validateSide(participant);
    if (participant != await _profileRepository.loadCurrentSide()) {
      throw StateError('A participant cannot change the partner mood.');
    }
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final all = _decode(prefs.getString(storageKey));
    final key = moodDateKey(date);
    final dayRaw = all[key];
    final day = dayRaw is Map<String, dynamic> ? dayRaw : <String, dynamic>{};
    final normalized = _normalizeDay(day, dateKey: key);
    final history = List<DailyMoodEntry>.from(
      normalized.histories[participant] ?? const [],
    );
    var timestamp = DateTime.now();
    if (history.isNotEmpty) {
      final previous = history.last.recordedAt ?? DateTime.parse(key);
      if (!timestamp.isAfter(previous)) {
        timestamp = previous.add(const Duration(microseconds: 1));
      }
    }
    final entry = DailyMoodEntry(
      dateKey: key,
      mood: mood,
      compliment: mood.complimentFor(key),
      recordedAt: timestamp,
    );
    history.add(entry);
    final nextDay = <String, Object?>{};
    for (final side in const ['first', 'second']) {
      final sideHistory = side == participant
          ? history
          : normalized.histories[side];
      if (sideHistory != null && sideHistory.isNotEmpty) {
        nextDay[side] = sideHistory.map((value) => value.toJson()).toList();
      }
    }
    all[key] = nextDay;
    final saved = await prefs.setString(storageKey, jsonEncode(all));
    if (!saved) throw StateError('Could not save participant mood.');
    return loadFor(date);
  }

  _NormalizedDay _normalizeDay(
    Map<String, dynamic> raw, {
    required String dateKey,
  }) {
    final values = Map<String, dynamic>.from(raw);
    var changed = false;
    for (final (legacy, stable) in [
      ('Алина', 'first'),
      ('Партнёр', 'second'),
    ]) {
      if (values.containsKey(legacy)) {
        values.putIfAbsent(stable, () => values[legacy]);
        values.remove(legacy);
        changed = true;
      }
    }
    final histories = <String, List<DailyMoodEntry>>{};
    for (final side in const ['first', 'second']) {
      final value = values[side];
      if (value is String) {
        final mood = DailyMood.values.where((item) => item.name == value);
        if (mood.isNotEmpty) {
          histories[side] = [
            DailyMoodEntry(
              dateKey: dateKey,
              mood: mood.first,
              compliment: mood.first.complimentFor(dateKey),
            ),
          ];
          changed = true;
        }
      } else if (value is List) {
        final entries = <DailyMoodEntry>[];
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            try {
              entries.add(DailyMoodEntry.fromJson(item));
            } on FormatException {
              continue;
            }
          }
        }
        entries.sort(_compareEntries);
        if (entries.isNotEmpty) histories[side] = entries;
      }
    }
    return _NormalizedDay(histories, values, changed);
  }

  static int _compareEntries(DailyMoodEntry a, DailyMoodEntry b) {
    final date = a.dateKey.compareTo(b.dateKey);
    if (date != 0) return date;
    return (a.recordedAt ?? DateTime.parse(a.dateKey)).compareTo(
      b.recordedAt ?? DateTime.parse(b.dateKey),
    );
  }

  static void _validateSide(String side) {
    if (side != 'first' && side != 'second') {
      throw ArgumentError.value(side, 'participant');
    }
  }

  Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Saved pair moods must be an object.');
    }

    return decoded;
  }
}

class _NormalizedDay {
  const _NormalizedDay(this.histories, this.value, this.changed);

  final Map<String, List<DailyMoodEntry>> histories;
  final Map<String, dynamic> value;
  final bool changed;
}
