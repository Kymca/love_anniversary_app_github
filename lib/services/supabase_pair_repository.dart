import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pair_room.dart';
import 'pair_repository.dart';

class SupabasePairRepository implements PairRepository {
  SupabasePairRepository(this.client, {this.preferences});

  static const activePairIdKey = 'supabase_active_pair_id_v1';

  final SupabaseClient client;
  final SharedPreferences? preferences;
  Future<void>? _anonymousSignIn;

  Future<SharedPreferences> get _store async =>
      preferences ?? await SharedPreferences.getInstance();

  @override
  Future<PairRoom> createPair(String name) async {
    final cleanName = _validateName(name);
    await _ensureAuthenticatedSession();
    try {
      final response = await client.rpc(
        'create_pair',
        params: {'p_name': cleanName},
      );
      return await _savePair(_roomFromResponse(response));
    } on PostgrestException catch (error) {
      throw PairRepositoryException(_translateError(error.message));
    }
  }

  @override
  Future<PairRoom> joinPair(String name, String code) async {
    final cleanName = _validateName(name);
    final cleanCode = code.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(cleanCode)) {
      throw const PairRepositoryException('Введите код пары из четырёх цифр.');
    }
    await _ensureAuthenticatedSession();
    try {
      final response = await client.rpc(
        'join_pair',
        params: {'p_code': cleanCode, 'p_name': cleanName},
      );
      return await _savePair(_roomFromResponse(response));
    } on PostgrestException catch (error) {
      throw PairRepositoryException(_translateError(error.message));
    }
  }

  @override
  Future<PairRoom?> loadActivePair() async {
    final store = await _store;
    final id = store.getString(activePairIdKey);
    final columns = 'id, code, first_name, second_name';
    if (id != null) {
      final row = await client
          .from('pairs')
          .select(columns)
          .eq('id', id)
          .maybeSingle();
      if (row != null) return _roomFromRow(row);
      await store.remove(activePairIdKey);
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final memberRow = await client
        .from('pairs')
        .select(columns)
        .or('first_user_id.eq.$userId,second_user_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (memberRow != null) {
      final room = _roomFromRow(memberRow);
      final roomId = room.id;
      if (roomId != null && !await store.setString(activePairIdKey, roomId)) {
        throw StateError('Could not save the active pair id.');
      }
      return room;
    }
    return null;
  }

  @override
  Future<void> deletePair(PairRoom room) async {
    final id = room.id;
    if (id == null) throw const FormatException('Backend pair has no id.');
    try {
      await client.rpc('delete_pair', params: {'p_pair_id': id});
      final store = await _store;
      if (store.getString(activePairIdKey) == id) {
        await store.remove(activePairIdKey);
      }
    } on PostgrestException catch (error) {
      throw PairRepositoryException(_translateError(error.message));
    }
  }

  Future<PairRoom> _savePair(PairRoom room) async {
    final id = room.id;
    if (id == null) throw const FormatException('Backend pair has no id.');
    final saved = await (await _store).setString(activePairIdKey, id);
    if (!saved) throw StateError('Could not save the active pair id.');
    return room;
  }

  PairRoom _roomFromResponse(Object? value) {
    if (value is! Map) {
      throw const FormatException('Backend returned an invalid pair.');
    }
    return _roomFromRow(Map<String, dynamic>.from(value));
  }

  PairRoom _roomFromRow(Map<String, dynamic> row) {
    final id = row['id'];
    final code = row['code'];
    final firstName = row['first_name'] ?? row['firstName'];
    final secondName = row['second_name'] ?? row['secondName'];
    if (id is! String ||
        code is! String ||
        firstName is! String ||
        (secondName != null && secondName is! String)) {
      throw const FormatException('Backend returned an invalid pair record.');
    }
    return PairRoom(
      id: id,
      code: code,
      members: [
        PairMember(name: firstName),
        if (secondName is String) PairMember(name: secondName),
      ],
    );
  }

  String _validateName(String name) {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) {
      throw const PairRepositoryException('Введите своё имя.');
    }
    if (cleanedName.length > 40) {
      throw const PairRepositoryException(
        'Имя должно быть короче 40 символов.',
      );
    }
    return cleanedName;
  }

  String _translateError(String message) => switch (message) {
    'verified_email_required' => 'pair_backend_migration_required',
    'invalid_name' => 'Введите своё имя.',
    'invalid_pair_code' => 'Введите код пары из четырёх цифр.',
    'pair_not_found' => 'Пара с таким кодом не найдена на сервере.',
    'pair_full' => 'В этой паре уже два участника.',
    'already_in_pair' => 'already_in_pair',
    _ => message,
  };

  Future<void> _ensureAuthenticatedSession() async {
    if (client.auth.currentUser != null) return;
    final signIn = _anonymousSignIn ??= _signInAnonymously();
    try {
      await signIn;
    } finally {
      if (identical(_anonymousSignIn, signIn)) _anonymousSignIn = null;
    }
  }

  Future<void> _signInAnonymously() async {
    final response = await client.auth.signInAnonymously();
    if (response.user == null || client.auth.currentUser == null) {
      throw AuthSessionMissingException(
        'Supabase did not create an authenticated guest session.',
      );
    }
  }
}
