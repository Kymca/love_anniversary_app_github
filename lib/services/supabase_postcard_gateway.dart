import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/postcard.dart';
import 'pair_repository.dart';
import 'postcard_delivery_gateway.dart';
import 'postcard_push_gateway.dart';

class SupabasePostcardGateway implements PostcardDeliveryGateway {
  SupabasePostcardGateway({required this.client, required this.pairRepository});

  final SupabaseClient client;
  final PairRepository pairRepository;

  Future<String> _pairId() async =>
      (await pairRepository.loadActivePair())?.id ??
      (throw StateError('Join a pair before sending postcards.'));

  @override
  Future<Postcard> sendPostcard({
    required String recipientId,
    required String message,
  }) async {
    final response = await client.rpc(
      'send_pair_postcard',
      params: {'p_pair_id': await _pairId(), 'p_message': message.trim()},
    );
    if (response is! Map) {
      throw const FormatException('Backend returned an invalid postcard.');
    }
    return _fromRow(
      Map<String, dynamic>.from(response),
      PostcardDirection.sent,
      'peerName',
    );
  }

  @override
  Future<Postcard?> loadReceivedPostcard(String postcardId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in before loading postcards.');
    final row = await client
        .from('pair_postcards')
        .select('id, message, created_at, sender_name')
        .eq('id', postcardId)
        .eq('recipient_user_id', userId)
        .maybeSingle();
    return row == null
        ? null
        : _fromRow(row, PostcardDirection.received, 'sender_name');
  }

  @override
  Future<List<Postcard>> loadReceivedPostcards() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in before loading postcards.');
    final rows = await client
        .from('pair_postcards')
        .select('id, message, created_at, sender_name')
        .eq('recipient_user_id', userId)
        .order('created_at', ascending: false);
    return List.unmodifiable(
      rows.map(
        (row) => _fromRow(row, PostcardDirection.received, 'sender_name'),
      ),
    );
  }

  Postcard _fromRow(
    Map<String, dynamic> row,
    PostcardDirection direction,
    String nameField,
  ) {
    if (row['id'] is! String ||
        row['message'] is! String ||
        (row['created_at'] ?? row['createdAt']) is! String ||
        row[nameField] is! String) {
      throw const FormatException('Backend returned an invalid postcard.');
    }
    return Postcard(
      id: row['id'] as String,
      message: row['message'] as String,
      createdAt: DateTime.parse(
        (row['created_at'] ?? row['createdAt']) as String,
      ),
      direction: direction,
      peerName: row[nameField] as String,
    );
  }
}

class SupabasePostcardRealtimeGateway implements PostcardPushGateway {
  SupabasePostcardRealtimeGateway(this.client);

  final SupabaseClient client;

  @override
  Stream<String> get receivedPostcardIds async* {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in before receiving postcards.');
    var isInitialSnapshot = true;
    final seenIds = <String>{};
    await for (final rows
        in client
            .from('pair_postcards')
            .stream(primaryKey: ['id'])
            .eq('recipient_user_id', userId)) {
      if (isInitialSnapshot) {
        seenIds.addAll(rows.map((row) => row['id']).whereType<String>());
        isInitialSnapshot = false;
        continue;
      }
      for (final row in rows) {
        final id = row['id'];
        if (id is String && seenIds.add(id)) yield id;
      }
    }
  }
}
