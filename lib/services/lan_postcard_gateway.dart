import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/postcard.dart';
import 'lan_postcard_config.dart';
import 'postcard_delivery_gateway.dart';

class LanPostcardGateway implements PostcardDeliveryGateway {
  LanPostcardGateway({
    required this.config,
    required this.senderName,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final LanPostcardConfig config;
  final String senderName;
  final http.Client _client;

  Uri get _baseUri => Uri.parse(config.baseUrl);

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${config.token}',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  @override
  Future<Postcard> sendPostcard({
    required String recipientId,
    required String message,
  }) async {
    config.validate();
    if (senderName.trim().isEmpty) {
      throw const FormatException('Set your participant name before sending.');
    }
    final response = await _client.post(
      _baseUri.resolve('/v1/postcards'),
      headers: _headers,
      body: jsonEncode({
        'senderSide': config.side,
        'recipientSide': config.otherSide,
        'senderName': senderName.trim(),
        'recipientName': recipientId.trim(),
        'message': message.trim(),
      }),
    );
    final data = _decodeResponse(response);
    if (response.statusCode != 201) {
      throw _gatewayError(response.statusCode, data);
    }
    return _toPostcard(data, PostcardDirection.sent, recipientId.trim());
  }

  @override
  Future<Postcard?> loadReceivedPostcard(String postcardId) async {
    config.validate();
    final response = await _client.get(
      _baseUri.resolve(
        '/v1/postcards/${Uri.encodeComponent(postcardId)}?side=${config.side}',
      ),
      headers: _headers,
    );
    final data = _decodeResponse(response);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw _gatewayError(response.statusCode, data);
    }
    return _toPostcard(data, PostcardDirection.received, '');
  }

  @override
  Future<List<Postcard>> loadReceivedPostcards() async {
    config.validate();
    final response = await _client.get(
      _baseUri.resolve('/v1/postcards?side=${config.side}'),
      headers: _headers,
    );
    final data = _decodeResponse(response);
    if (response.statusCode != 200) {
      throw _gatewayError(response.statusCode, data);
    }
    final postcards = data['postcards'];
    if (postcards is! List) {
      throw const FormatException('Postcard server returned an invalid inbox.');
    }
    return postcards
        .map(
          (entry) => _toPostcard(
            Map<String, dynamic>.from(entry as Map),
            PostcardDirection.received,
            '',
          ),
        )
        .toList();
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Postcard server returned invalid JSON.');
    }
    return data;
  }

  Postcard _toPostcard(
    Map<String, dynamic> data,
    PostcardDirection direction,
    String fallbackPeerName,
  ) {
    if (data['id'] is! String ||
        data['message'] is! String ||
        data['createdAt'] is! String) {
      throw const FormatException(
        'Postcard server returned an invalid record.',
      );
    }
    return Postcard(
      id: data['id'] as String,
      message: data['message'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      direction: direction,
      peerName:
          (direction == PostcardDirection.sent
                  ? data['recipientName']
                  : data['senderName'])
              as String? ??
          fallbackPeerName,
    );
  }

  Exception _gatewayError(int statusCode, Map<String, dynamic> data) =>
      LanPostcardException(
        statusCode,
        data['error'] is String ? data['error'] as String : 'request_failed',
      );
}

class LanPostcardException implements Exception {
  const LanPostcardException(this.statusCode, this.code);

  final int statusCode;
  final String code;

  @override
  String toString() => 'Postcard server error ($statusCode): $code';
}
