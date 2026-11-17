import 'package:shared_preferences/shared_preferences.dart';

import '../models/pair_room.dart';

class ParticipantProfileRepository {
  ParticipantProfileRepository({this.preferences});

  static const firstNameKey = 'participant_name_first_v1';
  static const secondNameKey = 'participant_name_second_v1';
  static const currentSideKey = 'current_participant_side_v1';

  final SharedPreferences? preferences;

  Future<SharedPreferences> get _store async =>
      preferences ?? await SharedPreferences.getInstance();

  Future<Map<String, String>> loadNames({PairRoom? pair}) async {
    final store = await _store;
    final names = <String, String>{};
    const sides = ['first', 'second'];
    for (var index = 0; index < sides.length; index++) {
      final side = sides[index];
      final key = _keyFor(side);
      final pairedName = pair != null && pair.members.length > index
          ? pair.members[index].name.trim()
          : null;
      var name = pairedName?.isNotEmpty == true
          ? pairedName
          : store.getString(key)?.trim();
      if (pairedName != null &&
          pairedName.isNotEmpty &&
          store.getString(key) != pairedName) {
        if (!await store.setString(key, pairedName)) {
          throw StateError('Could not synchronize participant name.');
        }
      }
      if (name != null && name.isNotEmpty) names[side] = name;
    }
    return names;
  }

  Future<String> loadCurrentSide() async {
    final side = (await _store).getString(currentSideKey);
    return side == 'second' ? 'second' : 'first';
  }

  Future<void> saveCurrentSide(String side) async {
    if (side != 'first' && side != 'second') {
      throw ArgumentError.value(side, 'side');
    }
    final saved = await (await _store).setString(currentSideKey, side);
    if (!saved) throw StateError('Could not save current participant side.');
  }

  Future<void> saveName(String side, String name) async {
    final key = _keyFor(side);
    final cleanedName = name.trim();
    if (cleanedName.isEmpty || cleanedName.length > 40) {
      throw ArgumentError.value(name, 'name', 'Must contain 1-40 characters.');
    }
    final saved = await (await _store).setString(key, cleanedName);
    if (!saved) throw StateError('Could not save participant name.');
  }

  static String _keyFor(String side) => switch (side) {
    'first' => firstNameKey,
    'second' => secondNameKey,
    _ => throw ArgumentError.value(side, 'side'),
  };
}
