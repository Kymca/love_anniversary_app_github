import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'daily_cinema.dart';

abstract interface class DailyCinemaRepository {
  Future<List<DailyCinemaFilm>> loadAvailableFilms(DateTime now);
  Future<void> addCustomFilm(String title);
  Future<void> removeFilmForToday(String id, DateTime now);
  Future<void> snoozeFilmForWeek(String id, DateTime now);
}

class SharedPreferencesDailyCinemaRepository implements DailyCinemaRepository {
  SharedPreferencesDailyCinemaRepository({this.preferences});

  static const _customFilmsKey = 'daily_cinema_custom_films_v1';
  static const _snoozedFilmsKey = 'daily_cinema_snoozed_films_v1';
  static const _removedTodayKeyPrefix = 'daily_cinema_removed_today_v1_';

  final SharedPreferences? preferences;

  Future<SharedPreferences> get _preferences async =>
      preferences ?? await SharedPreferences.getInstance();

  @override
  Future<List<DailyCinemaFilm>> loadAvailableFilms(DateTime now) async {
    final prefs = await _preferences;
    final todayKey = '$_removedTodayKeyPrefix${_localDateKey(now)}';
    await _removeOldDayLists(prefs, todayKey);
    final removedToday = prefs.getStringList(todayKey)?.toSet() ?? {};

    final snoozedUntil = _readSnoozedFilms(prefs);
    final nowMillis = now.millisecondsSinceEpoch;
    snoozedUntil.removeWhere((_, expiry) => expiry <= nowMillis);
    await prefs.setString(_snoozedFilmsKey, jsonEncode(snoozedUntil));

    final films = <DailyCinemaFilm>[
      ...dailyCinemaCatalog,
      ..._readCustomFilms(prefs),
    ];
    final seenTitles = <String>{};
    return List.unmodifiable(
      films.where((film) {
        if (removedToday.contains(film.id) ||
            snoozedUntil.containsKey(film.id)) {
          return false;
        }
        final titleKeys = {
          film.titleRu.trim().toLowerCase(),
          film.titleUk.trim().toLowerCase(),
        };
        if (titleKeys.any(seenTitles.contains)) return false;
        seenTitles.addAll(titleKeys);
        return true;
      }),
    );
  }

  @override
  Future<void> addCustomFilm(String title) async {
    final value = title.trim();
    if (value.isEmpty) throw ArgumentError.value(title, 'title');
    final prefs = await _preferences;
    final films = _readCustomFilms(prefs);
    final normalized = value.toLowerCase();
    final isDuplicate = [...dailyCinemaCatalog, ...films].any(
      (film) =>
          film.titleRu.trim().toLowerCase() == normalized ||
          film.titleUk.trim().toLowerCase() == normalized,
    );
    if (isDuplicate) return;

    films.add(
      DailyCinemaFilm(id: 'custom:$normalized', titleRu: value, titleUk: value),
    );
    await prefs.setString(
      _customFilmsKey,
      jsonEncode([
        for (final film in films)
          {'id': film.id, 'titleRu': film.titleRu, 'titleUk': film.titleUk},
      ]),
    );
  }

  @override
  Future<void> removeFilmForToday(String id, DateTime now) async {
    final prefs = await _preferences;
    final key = '$_removedTodayKeyPrefix${_localDateKey(now)}';
    final removed = prefs.getStringList(key) ?? [];
    if (removed.contains(id)) return;
    removed.add(id);
    await prefs.setStringList(key, removed);
  }

  @override
  Future<void> snoozeFilmForWeek(String id, DateTime now) async {
    final prefs = await _preferences;
    final snoozedUntil = _readSnoozedFilms(prefs)
      ..[id] = now.add(const Duration(days: 7)).millisecondsSinceEpoch;
    await prefs.setString(_snoozedFilmsKey, jsonEncode(snoozedUntil));
  }

  List<DailyCinemaFilm> _readCustomFilms(SharedPreferences prefs) {
    final json = prefs.getString(_customFilmsKey);
    if (json == null) return [];
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Custom cinema films must be a list.');
    }
    return [
      for (final value in decoded)
        if (value is Map &&
            value['id'] is String &&
            value['titleRu'] is String &&
            value['titleUk'] is String)
          DailyCinemaFilm(
            id: value['id'] as String,
            titleRu: value['titleRu'] as String,
            titleUk: value['titleUk'] as String,
          )
        else
          throw const FormatException('Invalid custom cinema film.'),
    ];
  }

  Map<String, int> _readSnoozedFilms(SharedPreferences prefs) {
    final json = prefs.getString(_snoozedFilmsKey);
    if (json == null) return {};
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('Snoozed cinema films must be a map.');
    }
    final snoozedFilms = <String, int>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String || entry.value is! int) {
        throw const FormatException('Invalid snoozed cinema film.');
      }
      snoozedFilms[entry.key as String] = entry.value as int;
    }
    return snoozedFilms;
  }

  Future<void> _removeOldDayLists(
    SharedPreferences prefs,
    String currentKey,
  ) async {
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_removedTodayKeyPrefix) && key != currentKey) {
        await prefs.remove(key);
      }
    }
  }

  String _localDateKey(DateTime instant) {
    final local = instant.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
