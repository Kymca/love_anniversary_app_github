import 'package:shared_preferences/shared_preferences.dart';

enum RouletteCategory { food, movie, activity }

abstract interface class RouletteRepository {
  Future<List<String>> loadCustomChoices(RouletteCategory category);
  Future<void> addChoice(RouletteCategory category, String choice);
  Future<void> removeChoice(RouletteCategory category, String choice);
}

class SharedPreferencesRouletteRepository implements RouletteRepository {
  SharedPreferencesRouletteRepository({this.preferences});

  static const _keyPrefix = 'date_roulette_custom_v1_';

  final SharedPreferences? preferences;

  String _key(RouletteCategory category) => '$_keyPrefix${category.name}';

  Future<SharedPreferences> get _preferences async =>
      preferences ?? await SharedPreferences.getInstance();

  @override
  Future<List<String>> loadCustomChoices(RouletteCategory category) async {
    final values = (await _preferences).getStringList(_key(category)) ?? [];
    return List.unmodifiable(values);
  }

  @override
  Future<void> addChoice(RouletteCategory category, String choice) async {
    final value = choice.trim();
    if (value.isEmpty) throw ArgumentError.value(choice, 'choice');
    final prefs = await _preferences;
    final values = prefs.getStringList(_key(category)) ?? [];
    if (values.any(
      (existing) => existing.toLowerCase() == value.toLowerCase(),
    )) {
      return;
    }
    values.add(value);
    await prefs.setStringList(_key(category), values);
  }

  @override
  Future<void> removeChoice(RouletteCategory category, String choice) async {
    final prefs = await _preferences;
    final values = prefs.getStringList(_key(category)) ?? [];
    values.remove(choice);
    await prefs.setStringList(_key(category), values);
  }
}
