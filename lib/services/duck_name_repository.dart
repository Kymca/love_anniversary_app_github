import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class DuckNameRepository {
  bool get isSynchronized;

  Future<String?> loadName(String? pairId);
  Future<bool> claimNamingPrompt(String? pairId);
  Future<String> saveName(String? pairId, String name);
  Stream<String?> watchName(String? pairId);
}

class SharedPreferencesDuckNameRepository implements DuckNameRepository {
  SharedPreferencesDuckNameRepository({this.preferences});

  static const nameKey = 'tamagotchi_name';
  final SharedPreferences? preferences;

  @override
  bool get isSynchronized => false;

  Future<SharedPreferences> get _store async =>
      preferences ?? await SharedPreferences.getInstance();

  @override
  Future<String?> loadName(String? pairId) async =>
      (await _store).getString(nameKey);

  @override
  Future<bool> claimNamingPrompt(String? pairId) async => true;

  @override
  Future<String> saveName(String? pairId, String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty || cleaned.length > 24) {
      throw ArgumentError.value(name, 'name');
    }
    if (!await (await _store).setString(nameKey, cleaned)) {
      throw StateError('Could not save duck name.');
    }
    return cleaned;
  }

  @override
  Stream<String?> watchName(String? pairId) => const Stream.empty();
}

class SupabaseDuckNameRepository implements DuckNameRepository {
  SupabaseDuckNameRepository(this.client);

  final SupabaseClient client;

  @override
  bool get isSynchronized => true;

  String _requirePair(String? pairId) =>
      pairId ?? (throw StateError('Join a pair before naming the duck.'));

  @override
  Future<String?> loadName(String? pairId) async {
    final row = await client
        .from('pairs')
        .select('duck_name')
        .eq('id', _requirePair(pairId))
        .single();
    return row['duck_name'] as String?;
  }

  @override
  Future<bool> claimNamingPrompt(String? pairId) async {
    final claimed = await client.rpc(
      'claim_duck_naming',
      params: {'p_pair_id': _requirePair(pairId)},
    );
    return claimed == true;
  }

  @override
  Future<String> saveName(String? pairId, String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty || cleaned.length > 24) {
      throw ArgumentError.value(name, 'name');
    }
    final saved = await client.rpc(
      'set_duck_name',
      params: {'p_pair_id': _requirePair(pairId), 'p_name': cleaned},
    );
    if (saved is! String || saved.isEmpty) {
      throw const FormatException('Backend returned an invalid duck name.');
    }
    return saved;
  }

  @override
  Stream<String?> watchName(String? pairId) {
    final id = _requirePair(pairId);
    return client
        .from('pairs')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((rows) => rows.isEmpty ? null : rows.first['duck_name'] as String?)
        .distinct();
  }
}
