import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_mood.dart';

class MoodRepository {
  MoodRepository({this.preferences});

  static const storageKey = 'daily_mood_entries_v1';

  final SharedPreferences? preferences;

  Future<List<DailyMoodEntry>> load() async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final data = jsonDecode(raw);
    if (data is! List) {
      throw const FormatException('Saved mood history must be a list.');
    }
    final entries = <DailyMoodEntry>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      try {
        entries.add(DailyMoodEntry.fromJson(item));
      } on FormatException {
        continue;
      }
    }
    entries.sort(_compareEntries);
    return List.unmodifiable(entries);
  }

  Future<List<DailyMoodEntry>> historyFor(DateTime date) async {
    final key = moodDateKey(date);
    return List.unmodifiable(
      (await load()).where((entry) => entry.dateKey == key),
    );
  }

  Future<DailyMoodEntry?> entryFor(DateTime date) async {
    final key = moodDateKey(date);
    final entries = (await load()).where((entry) => entry.dateKey == key);
    return entries.isEmpty ? null : entries.last;
  }

  Future<DailyMoodEntry?> recordToday(
    DailyMood mood, {
    required DateTime now,
  }) => record(mood, date: now, recordedAt: now);

  Future<DailyMoodEntry> record(
    DailyMood mood, {
    required DateTime date,
    DateTime? recordedAt,
  }) async {
    final entries = await load();
    final key = moodDateKey(date);
    final dateEntries = entries.where((entry) => entry.dateKey == key);
    var timestamp = recordedAt ?? DateTime.now();
    if (dateEntries.isNotEmpty) {
      final previousTimestamp =
          dateEntries.last.recordedAt ?? DateTime.parse(key);
      if (!timestamp.isAfter(previousTimestamp)) {
        timestamp = previousTimestamp.add(const Duration(microseconds: 1));
      }
    }
    final entry = DailyMoodEntry(
      dateKey: key,
      mood: mood,
      compliment: mood.complimentFor(key),
      recordedAt: timestamp,
    );
    await _save([...entries, entry]);
    return entry;
  }

  Future<void> _save(List<DailyMoodEntry> entries) async {
    entries.sort(_compareEntries);
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  static int _compareEntries(DailyMoodEntry a, DailyMoodEntry b) {
    final dateComparison = a.dateKey.compareTo(b.dateKey);
    if (dateComparison != 0) return dateComparison;
    final aTime = a.recordedAt ?? DateTime.parse(a.dateKey);
    final bTime = b.recordedAt ?? DateTime.parse(b.dateKey);
    return aTime.compareTo(bTime);
  }
}
