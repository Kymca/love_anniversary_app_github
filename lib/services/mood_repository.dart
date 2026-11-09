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
    entries.sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return List.unmodifiable(entries);
  }

  Future<DailyMoodEntry?> entryFor(DateTime date) async {
    final key = moodDateKey(date);
    for (final entry in await load()) {
      if (entry.dateKey == key) return entry;
    }
    return null;
  }

  Future<DailyMoodEntry?> recordToday(
    DailyMood mood, {
    required DateTime now,
  }) async {
    final entries = await load();
    final key = moodDateKey(now);
    if (entries.any((entry) => entry.dateKey == key)) return null;
    final entry = DailyMoodEntry(
      dateKey: key,
      mood: mood,
      compliment: mood.complimentFor(key),
    );
    await _save([...entries, entry]);
    return entry;
  }

  Future<void> _save(List<DailyMoodEntry> entries) async {
    entries.sort((a, b) => a.dateKey.compareTo(b.dateKey));
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }
}
