import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum RouletteCategory { food, movie, activity }

class RouletteSpin {
  const RouletteSpin({
    required this.id,
    required this.category,
    required this.choiceKey,
    required this.choice,
    required this.startedAt,
  });

  final String id;
  final RouletteCategory category;
  final String choiceKey;
  final String choice;
  final DateTime startedAt;

  factory RouletteSpin.fromJson(Map<String, dynamic> json) {
    final id = json['spin_id'];
    final categoryName = json['category'];
    final choiceKey = json['choice_key'];
    final choice = json['choice'];
    final startedAt = json['started_at'];
    RouletteCategory? category;
    for (final value in RouletteCategory.values) {
      if (value.name == categoryName) {
        category = value;
        break;
      }
    }
    if (id is! String ||
        category == null ||
        choiceKey is! String ||
        choice is! String ||
        startedAt is! String) {
      throw const FormatException('Backend returned an invalid roulette spin.');
    }
    final parsedStartedAt = DateTime.tryParse(startedAt);
    if (parsedStartedAt == null) {
      throw const FormatException('Backend returned an invalid roulette spin.');
    }
    return RouletteSpin(
      id: id,
      category: category,
      choiceKey: choiceKey,
      choice: choice,
      startedAt: parsedStartedAt.toUtc(),
    );
  }
}

abstract interface class RouletteRepository {
  Future<List<String>> loadSharedChoices(RouletteCategory category);
  Future<List<String>> loadCustomChoices(RouletteCategory category);
  Future<List<String>> loadExcludedChoiceKeys(RouletteCategory category);
  Future<void> addChoice(RouletteCategory category, String choice);
  Future<void> removeChoice(RouletteCategory category, String choice);
  Future<void> applyChoice(
    RouletteCategory category,
    String choice,
    String choiceKey,
  );
  Stream<void> watchChanges(RouletteCategory category);
  Future<RouletteSpin?> startSpin(
    RouletteCategory category,
    String choice,
    String choiceKey,
  );
  Stream<RouletteSpin> watchSpins();
}

class SharedPreferencesRouletteRepository implements RouletteRepository {
  SharedPreferencesRouletteRepository({
    this.preferences,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const _keyPrefix = 'date_roulette_custom_v1_';
  static const _inactiveKeyPrefix = 'date_roulette_inactive_v1_';
  static const _exclusionsKeyPrefix = 'date_roulette_exclusions_v1_';
  static var _localSpinSequence = 0;

  final SharedPreferences? preferences;
  final DateTime Function() _clock;

  String _key(RouletteCategory category) => '$_keyPrefix${category.name}';
  String _inactiveKey(RouletteCategory category) =>
      '$_inactiveKeyPrefix${category.name}';
  String _exclusionsKey(RouletteCategory category) =>
      '$_exclusionsKeyPrefix${category.name}';

  Future<SharedPreferences> get _store async =>
      preferences ?? await SharedPreferences.getInstance();

  @override
  Future<List<String>> loadSharedChoices(RouletteCategory category) async =>
      List.unmodifiable((await _store).getStringList(_key(category)) ?? []);

  @override
  Future<List<String>> loadCustomChoices(RouletteCategory category) async {
    final prefs = await _store;
    final all = prefs.getStringList(_key(category)) ?? [];
    final inactive = prefs.getStringList(_inactiveKey(category))?.toSet() ?? {};
    final excluded = (await loadExcludedChoiceKeys(category)).toSet();
    return List.unmodifiable(
      all.where(
        (choice) =>
            !inactive.contains(choice) &&
            !excluded.contains(customChoiceKey(choice)),
      ),
    );
  }

  @override
  Future<List<String>> loadExcludedChoiceKeys(RouletteCategory category) async {
    final prefs = await _store;
    final raw = prefs.getString(_exclusionsKey(category));
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Roulette exclusions must be an object.');
    }

    final now = _clock().toUtc();
    final active = <String, Map<String, dynamic>>{};
    final excludedKeys = <String>[];
    for (final entry in decoded.entries) {
      if (entry.value is! Map<String, dynamic>) {
        throw const FormatException('Invalid roulette exclusion.');
      }
      final item = entry.value as Map<String, dynamic>;
      var watched = item['watched'];
      final until = item['until'];
      if (watched is! bool || (until != null && until is! String)) {
        throw const FormatException('Invalid roulette exclusion.');
      }
      final expiry = until is String ? DateTime.tryParse(until)?.toUtc() : null;
      if (category == RouletteCategory.movie &&
          !watched &&
          expiry != null &&
          !expiry.isAfter(now)) {
        watched = true;
        active[entry.key] = {'watched': true, 'until': null};
        excludedKeys.add(entry.key);
      } else if (watched ||
          (category != RouletteCategory.movie &&
              expiry != null &&
              expiry.isAfter(now))) {
        active[entry.key] = item;
        excludedKeys.add(entry.key);
      } else if (category == RouletteCategory.movie &&
          !watched &&
          expiry != null &&
          expiry.isAfter(now)) {
        active[entry.key] = item;
      }
    }
    await prefs.setString(_exclusionsKey(category), jsonEncode(active));
    return List.unmodifiable(excludedKeys);
  }

  @override
  Future<void> addChoice(RouletteCategory category, String choice) async {
    final value = choice.trim();
    if (value.isEmpty || value.length > 80) {
      throw ArgumentError.value(choice, 'choice');
    }
    final prefs = await _store;
    final values = prefs.getStringList(_key(category)) ?? [];
    final existing = values.indexWhere(
      (item) => item.toLowerCase() == value.toLowerCase(),
    );
    if (existing >= 0) {
      final inactive = prefs.getStringList(_inactiveKey(category)) ?? [];
      inactive.removeWhere(
        (item) => item.toLowerCase() == values[existing].toLowerCase(),
      );
      await prefs.setStringList(_inactiveKey(category), inactive);
      return;
    }
    values.add(value);
    await prefs.setStringList(_key(category), values);
  }

  @override
  Future<void> removeChoice(RouletteCategory category, String choice) async {
    final prefs = await _store;
    final values = prefs.getStringList(_key(category)) ?? [];
    final inactive = prefs.getStringList(_inactiveKey(category)) ?? [];
    for (final value in values.where(
      (item) => item.toLowerCase() == choice.trim().toLowerCase(),
    )) {
      if (!inactive.contains(value)) inactive.add(value);
    }
    await prefs.setStringList(_inactiveKey(category), inactive);
  }

  @override
  Future<void> applyChoice(
    RouletteCategory category,
    String choice,
    String choiceKey,
  ) async {
    final normalizedKey = choiceKey.trim();
    if (choice.trim().isEmpty || normalizedKey.isEmpty) {
      throw ArgumentError.value(choiceKey, 'choiceKey');
    }
    final prefs = await _store;
    final raw = prefs.getString(_exclusionsKey(category));
    final decoded = raw == null ? <String, dynamic>{} : jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Roulette exclusions must be an object.');
    }
    final now = _clock().toUtc();
    decoded[normalizedKey] = {
      'watched': false,
      'until': category == RouletteCategory.movie
          ? DateTime.utc(now.year, now.month, now.day + 1).toIso8601String()
          : now.add(const Duration(days: 2)).toIso8601String(),
    };
    await prefs.setString(_exclusionsKey(category), jsonEncode(decoded));
  }

  @override
  Stream<void> watchChanges(RouletteCategory category) => const Stream.empty();

  @override
  Future<RouletteSpin?> startSpin(
    RouletteCategory category,
    String choice,
    String choiceKey,
  ) async {
    final now = _clock().toUtc();
    return RouletteSpin(
      id: 'local-${now.microsecondsSinceEpoch}-${_localSpinSequence++}',
      category: category,
      choiceKey: choiceKey,
      choice: choice,
      startedAt: now,
    );
  }

  @override
  Stream<RouletteSpin> watchSpins() => const Stream.empty();

  static String customChoiceKey(String choice) =>
      'custom:${choice.trim().toLowerCase()}';
}
