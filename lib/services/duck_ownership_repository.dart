import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_mood.dart';
import 'participant_profile_repository.dart';

class DuckNotOwnedException implements Exception {
  const DuckNotOwnedException();

  @override
  String toString() => 'The current participant does not own the duck today.';
}

abstract interface class DuckOwnershipService {
  Future<String> ownerFor(DateTime date);
  Future<bool> isCurrentParticipantOwner(DateTime date);
  Future<String> requireCurrentOwner(DateTime date);
  Future<void> requireParticipantSide(String side);
}

class DuckOwnershipRepository implements DuckOwnershipService {
  DuckOwnershipRepository({
    this.preferences,
    ParticipantProfileRepository? profileRepository,
  }) : _profileRepository =
           profileRepository ??
           ParticipantProfileRepository(preferences: preferences);

  static const storageKey = 'daily_duck_owner_v1';

  final SharedPreferences? preferences;
  final ParticipantProfileRepository _profileRepository;

  @override
  Future<String> ownerFor(DateTime date) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final key = moodDateKey(date);
    final raw = prefs.getString(storageKey);
    Map<String, dynamic> state = {};
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Saved duck ownership must be an object.');
      }
      state = decoded;
    }

    final savedDate = state['date'];
    final savedSide = state['side'];
    if (savedDate == key && (savedSide == 'first' || savedSide == 'second')) {
      return savedSide as String;
    }

    var owner = 'first';
    if (savedDate is String &&
        (savedSide == 'first' || savedSide == 'second')) {
      final previous = DateTime.tryParse(savedDate);
      if (previous != null && DateTime.parse(key).isAfter(previous)) {
        final elapsedDays = DateTime.parse(key).difference(previous).inDays;
        if (elapsedDays.isOdd) {
          owner = savedSide == 'first' ? 'second' : 'first';
        } else {
          owner = savedSide as String;
        }
      }
    }
    final saved = await prefs.setString(
      storageKey,
      jsonEncode({'date': key, 'side': owner}),
    );
    if (!saved) throw StateError('Could not persist daily duck owner.');
    return owner;
  }

  @override
  Future<bool> isCurrentParticipantOwner(DateTime date) async {
    final side = await _profileRepository.loadCurrentSide();
    return side == await ownerFor(date);
  }

  @override
  Future<String> requireCurrentOwner(DateTime date) async {
    final side = await _profileRepository.loadCurrentSide();
    if (side != await ownerFor(date)) throw const DuckNotOwnedException();
    return side;
  }

  @override
  Future<void> requireParticipantSide(String side) async {
    if (side != await _profileRepository.loadCurrentSide()) {
      throw const DuckNotOwnedException();
    }
  }
}
