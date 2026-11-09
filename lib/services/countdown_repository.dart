import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/countdown_event.dart';

class CountdownRepository {
  CountdownRepository({this.preferences, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'countdown_events_v1';

  final SharedPreferences? preferences;
  final DateTime Function() _clock;

  Future<List<CountdownEvent>> load() async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final data = jsonDecode(raw);
    if (data is! List) {
      throw const FormatException('Saved countdown events must be a list.');
    }
    final events = <CountdownEvent>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      try {
        events.add(CountdownEvent.fromJson(item));
      } on FormatException {
        continue;
      }
    }
    events.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return List.unmodifiable(events);
  }

  Future<CountdownEvent> add({
    required String title,
    required DateTime eventDate,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be empty.');
    }
    final now = _clock();
    final event = CountdownEvent(
      id: now.microsecondsSinceEpoch.toString(),
      title: cleanTitle,
      eventDate: eventDate,
      createdAt: now,
    );
    await _save([...await load(), event]);
    return event;
  }

  Future<CountdownEvent> update({
    required String id,
    required String title,
    required DateTime eventDate,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be empty.');
    }
    final events = [...await load()];
    final index = events.indexWhere((event) => event.id == id);
    if (index < 0) throw StateError('Countdown event not found.');
    final old = events[index];
    final updated = CountdownEvent(
      id: old.id,
      title: cleanTitle,
      eventDate: eventDate,
      createdAt: old.createdAt,
    );
    events[index] = updated;
    await _save(events);
    return updated;
  }

  Future<void> delete(String id) async {
    final events = await load();
    await _save(events.where((event) => event.id != id).toList());
  }

  Future<void> _save(List<CountdownEvent> events) async {
    events.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(events.map((event) => event.toJson()).toList()),
    );
  }
}
