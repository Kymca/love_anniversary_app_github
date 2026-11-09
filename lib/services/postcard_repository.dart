import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/postcard.dart';

class PostcardRepository {
  PostcardRepository({this.preferences});

  static const storageKey = 'postcard_archive_v1';
  final SharedPreferences? preferences;

  Future<SharedPreferences> get _store async =>
      preferences ?? await SharedPreferences.getInstance();

  Future<List<Postcard>> load() async {
    final encoded = (await _store).getString(storageKey);
    if (encoded == null) return const [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Postcard archive must be a list');
    }
    return decoded
        .map((entry) => Postcard.fromJson(entry as Map<String, dynamic>))
        .toList()
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
  }

  Future<void> recordSent(Postcard postcard) =>
      _save(postcard, PostcardDirection.sent);

  Future<void> recordReceived(Postcard postcard) =>
      _save(postcard, PostcardDirection.received);

  Future<void> _save(Postcard postcard, PostcardDirection direction) async {
    if (postcard.message.trim().isEmpty) {
      throw ArgumentError.value(
        postcard.message,
        'message',
        'Must not be empty.',
      );
    }
    final store = await _store;
    final cards = await load();
    final record = Postcard(
      id: postcard.id,
      message: postcard.message.trim(),
      createdAt: postcard.createdAt,
      direction: direction,
      peerName: postcard.peerName,
    );
    final updated = [
      record,
      ...cards.where((existing) => existing.id != postcard.id),
    ];
    final saved = await store.setString(
      storageKey,
      jsonEncode(updated.map((card) => card.toJson()).toList()),
    );
    if (!saved) throw StateError('Could not save postcard archive');
  }
}
