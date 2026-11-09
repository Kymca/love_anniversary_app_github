import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class TelegramBotApi {
  TelegramBotApi({
    String? token,
    required String chatId,
    Uri? endpoint,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _chatId = chatId,
       _endpoint = endpoint ?? _endpointForToken(token),
       _client = client ?? http.Client() {
    if (_chatId.trim().isEmpty) {
      throw ArgumentError.value(chatId, 'chatId', 'Must not be empty.');
    }
  }

  final String _chatId;
  final Uri _endpoint;
  final http.Client _client;
  final Duration timeout;

  static Uri _endpointForToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      throw ArgumentError('Provide a Telegram bot token or API endpoint.');
    }
    return Uri.https('api.telegram.org', '/bot$token/sendMessage');
  }

  Future<void> sendMessage(String text, {String? parseMode}) async {
    final payload = <String, Object?>{'chat_id': _chatId, 'text': text};
    if (parseMode != null) payload['parse_mode'] = parseMode;
    await _send('sendMessage', payload);
  }

  Future<void> sendSticker(String sticker) =>
      _sendMedia('sendSticker', 'sticker', sticker);

  Future<void> sendAnimation(String animation) =>
      _sendMedia('sendAnimation', 'animation', animation);

  Future<void> _sendMedia(String method, String field, String media) {
    if (media.trim().isEmpty) {
      throw ArgumentError.value(media, field, 'Must not be empty.');
    }
    return _send(method, {'chat_id': _chatId, field: media});
  }

  Future<void> _send(String method, Map<String, Object?> payload) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            _methodEndpoint(method),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const TelegramNotificationException(
        'Время ожидания ответа Telegram истекло.',
      );
    } on SocketException {
      throw const TelegramNotificationException(
        'Не удалось подключиться к Telegram.',
      );
    } on HttpException {
      throw const TelegramNotificationException(
        'Не удалось отправить уведомление в Telegram.',
      );
    } on http.ClientException {
      throw const TelegramNotificationException(
        'Не удалось отправить уведомление в Telegram.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TelegramNotificationException(
        'Telegram вернул HTTP ${response.statusCode}.',
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['ok'] != true) {
        throw const TelegramNotificationException(
          'Telegram отклонил уведомление.',
        );
      }
    } on FormatException {
      throw const TelegramNotificationException(
        'Telegram вернул некорректный ответ.',
      );
    }
  }

  Uri _methodEndpoint(String method) {
    final segments = _endpoint.pathSegments;
    final knownMethods = {'sendMessage', 'sendSticker', 'sendAnimation'};
    final path = segments.isNotEmpty && knownMethods.contains(segments.last)
        ? _endpoint.path.replaceFirst(
            RegExp('${RegExp.escape(segments.last)}\$'),
            method,
          )
        : '${_endpoint.path}/$method';
    return _endpoint.replace(path: path);
  }
}

class TelegramNotificationException implements Exception {
  const TelegramNotificationException(this.message);

  final String message;

  @override
  String toString() => message;
}
