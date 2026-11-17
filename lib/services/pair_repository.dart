import 'dart:math';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pair_room.dart';

abstract interface class PairRepository {
  Future<PairRoom> createPair(String name);
  Future<PairRoom> joinPair(String name, String code);
  Future<PairRoom?> loadActivePair();
  Future<void> deletePair(PairRoom room);
}

class InMemoryPairRepository implements PairRepository {
  InMemoryPairRepository({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;
  final Map<String, PairRoom> _rooms = {};
  String? _activeRoomCode;

  @override
  Future<PairRoom> createPair(String name) async {
    final cleanName = _validateName(name);
    for (var attempt = 0; attempt < 10000; attempt++) {
      final code = (1000 + _random.nextInt(9000)).toString();
      if (_rooms.containsKey(code)) continue;
      final room = PairRoom(
        code: code,
        members: [PairMember(name: cleanName)],
      );
      _rooms[code] = room;
      _activeRoomCode = code;
      return room;
    }
    throw StateError('Не удалось создать уникальный код пары.');
  }

  @override
  Future<PairRoom> joinPair(String name, String code) async {
    final cleanName = _validateName(name);
    final cleanCode = code.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(cleanCode)) {
      throw const PairRepositoryException('Введите код пары из четырёх цифр.');
    }
    final room = _rooms[cleanCode];
    if (room == null) {
      throw const PairRepositoryException(
        'Пара с таким кодом не найдена на этом устройстве.',
      );
    }
    if (room.members.length >= 2) {
      throw const PairRepositoryException('В этой паре уже два участника.');
    }
    final updated = PairRoom(
      code: room.code,
      members: [
        ...room.members,
        PairMember(name: cleanName),
      ],
    );
    _rooms[cleanCode] = updated;
    _activeRoomCode = cleanCode;
    return updated;
  }

  Future<PairRoom?> findPair(String code) async => _rooms[code];

  @override
  Future<void> deletePair(PairRoom room) async {
    _rooms.remove(room.code);
    if (_activeRoomCode == room.code) _activeRoomCode = null;
  }

  @override
  Future<PairRoom?> loadActivePair() async {
    final code = _activeRoomCode;
    return code == null ? null : _rooms[code];
  }

  String _validateName(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const PairRepositoryException('Введите своё имя.');
    }
    if (cleanName.length > 40) {
      throw const PairRepositoryException(
        'Имя должно быть короче 40 символов.',
      );
    }
    return cleanName;
  }
}

class SharedPreferencesPairRepository implements PairRepository {
  SharedPreferencesPairRepository({this.preferences, Random? random})
    : _random = random ?? Random.secure();

  static const storageKey = 'pair_rooms_v1';
  static const activePairKey = 'active_pair_code_v1';

  final SharedPreferences? preferences;
  final Random _random;

  @override
  Future<PairRoom> createPair(String name) async {
    final cleanName = _validateName(name);
    final rooms = await _loadMap();
    for (var attempt = 0; attempt < 10000; attempt++) {
      final code = (1000 + _random.nextInt(9000)).toString();
      if (rooms.containsKey(code)) continue;
      final room = PairRoom(
        code: code,
        members: [PairMember(name: cleanName)],
      );
      rooms[code] = room;
      await _save(rooms);
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await prefs.setString(activePairKey, code);
      return room;
    }
    throw StateError('Не удалось создать уникальный код пары.');
  }

  @override
  Future<PairRoom> joinPair(String name, String code) async {
    final cleanName = _validateName(name);
    final cleanCode = code.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(cleanCode)) {
      throw const PairRepositoryException('Введите код пары из четырёх цифр.');
    }
    final rooms = await _loadMap();
    final room = rooms[cleanCode];
    if (room == null) {
      throw const PairRepositoryException(
        'Пара с таким кодом не найдена на этом устройстве.',
      );
    }
    if (room.members.length >= 2) {
      throw const PairRepositoryException('В этой паре уже два участника.');
    }
    final updated = PairRoom(
      code: room.code,
      members: [
        ...room.members,
        PairMember(name: cleanName),
      ],
    );
    rooms[cleanCode] = updated;
    await _save(rooms);
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(activePairKey, cleanCode);
    return updated;
  }

  Future<PairRoom?> findPair(String code) async => (await _loadMap())[code];

  @override
  Future<PairRoom?> loadActivePair() async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final code = prefs.getString(activePairKey);
    return code == null ? null : findPair(code);
  }

  @override
  Future<void> deletePair(PairRoom room) async {
    final rooms = await _loadMap();
    rooms.remove(room.code);
    await _save(rooms);
    final prefs = preferences ?? await SharedPreferences.getInstance();
    if (prefs.getString(activePairKey) == room.code) {
      await prefs.remove(activePairKey);
    }
  }

  Future<Map<String, PairRoom>> _loadMap() async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Saved pair rooms must be an object.');
    }
    final rooms = <String, PairRoom>{};
    for (final entry in decoded.entries) {
      if (entry.value is! Map<String, dynamic>) continue;
      try {
        rooms[entry.key] = PairRoom.fromJson(entry.value);
      } on FormatException {
        continue;
      }
    }
    return rooms;
  }

  Future<void> _save(Map<String, PairRoom> rooms) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode({
        for (final entry in rooms.entries) entry.key: entry.value.toJson(),
      }),
    );
  }

  String _validateName(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const PairRepositoryException('Введите своё имя.');
    }
    if (cleanName.length > 40) {
      throw const PairRepositoryException(
        'Имя должно быть короче 40 символов.',
      );
    }
    return cleanName;
  }
}

class PairRepositoryException implements Exception {
  const PairRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
