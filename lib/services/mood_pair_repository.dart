import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_mood.dart';

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
  Future<DailyPairMood> loadFor(DateTime date);

  Future<DailyPairMood> record(
    String participant,
    DailyMood mood, {
    required DateTime date,
  });
}

class SharedPreferencesMoodPairRepository implements MoodPairRepository {
  SharedPreferencesMoodPairRepository({this.preferences});

  static const storageKey = 'same_device_pair_moods_v1';
  final SharedPreferences? preferences;

  @override
  Future<DailyPairMood> loadFor(DateTime date) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final all = _decode(prefs.getString(storageKey));
    var migrated = false;
    for (final value in all.values) {
      if (value is! Map<String, dynamic>) continue;
      if (value.containsKey('Партнёр') || value.containsKey('Алина')) {
        value.putIfAbsent('first', () => value['Алина']);
        value.putIfAbsent('second', () => value['Партнёр']);
        value.remove('Партнёр');
        value.remove('Алина');
        migrated = true;
      }
    }
    if (migrated) await prefs.setString(storageKey, jsonEncode(all));
    final key = moodDateKey(date);
    final raw = all[key];
    if (raw is! Map<String, dynamic>) {
      return DailyPairMood(dateKey: key, moods: const {});
    }
    return DailyPairMood(
      dateKey: key,
      moods: {
        for (final entry in raw.entries)
          if (entry.value is String)
            entry.key: DailyMood.values.firstWhere(
              (mood) => mood.name == entry.value,
              orElse: () => DailyMood.thoughtful,
            ),
      },
    );
  }

  @override
  Future<DailyPairMood> record(
    String participant,
    DailyMood mood, {
    required DateTime date,
  }) async {
    final side = switch (participant) {
      'first' || 'Алина' => 'first',
      'second' || 'Партнёр' => 'second',
      _ => null,
    };
    if (side == null) {
      throw ArgumentError.value(participant, 'participant');
    }
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final all = _decode(prefs.getString(storageKey));
    final key = moodDateKey(date);
    final day = Map<String, dynamic>.from(all[key] as Map? ?? {});
    day[side] = mood.name;
    all[key] = day;
    await prefs.setString(storageKey, jsonEncode(all));
    return loadFor(date);
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
