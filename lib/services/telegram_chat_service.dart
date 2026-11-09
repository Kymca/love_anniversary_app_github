import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_export.dart';
import 'chat_service.dart';

class SnippetMessage {
  const SnippetMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.timestamp,
  });

  final String id;
  final String author;
  final String text;
  final DateTime? timestamp;

  Map<String, Object?> toJson() => {
    'id': id,
    'author': author,
    'text': text,
    'timestamp': timestamp?.toIso8601String(),
  };

  factory SnippetMessage.fromJson(Map<String, dynamic> json) {
    return SnippetMessage(
      id: json['id'] as String,
      author: json['author'] as String,
      text: json['text'] as String,
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
    );
  }
}

class ChatSnippet {
  ChatSnippet({required this.id, required List<SnippetMessage> messages})
    : messages = List.unmodifiable(messages);

  final String id;
  final List<SnippetMessage> messages;

  Map<String, Object?> toJson() => {
    'id': id,
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  factory ChatSnippet.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    if (rawMessages is! List) {
      throw const FormatException('Favorite snippet messages must be a list.');
    }
    return ChatSnippet(
      id: json['id'] as String,
      messages: rawMessages.map((message) {
        if (message is! Map) {
          throw const FormatException(
            'Favorite snippet message must be an object.',
          );
        }
        return SnippetMessage.fromJson(Map<String, dynamic>.from(message));
      }).toList(),
    );
  }
}

class NoEligibleMemoryException implements Exception {
  const NoEligibleMemoryException()
    : message =
          'No eligible Telegram conversation found. A memory must contain '
          '6–10 consecutive, non-empty messages from both participants '
          'with at least 3 messages each and no negative triggers.';

  final String message;

  @override
  String toString() => 'NoEligibleMemoryException: $message';
}

class TelegramChatService {
  /// An optional local Telegram export can be bundled as `result.json`.
  TelegramChatService({
    AssetBundle? bundle,
    this.preferences,
    Random? random,
    this.assetPath = 'result.json',
  }) : _chatService = ChatService(bundle: bundle, assetPath: assetPath),
       _random = random ?? Random();

  static const favoritesKey = 'telegram_chat_favorites';
  static const negativeTriggers = <String>[
    'плачу из-за',
    'реву',
    'обиделась',
    'обиделся',
    'тупой',
    'заткнись',
    'не пиши мне',
    'хватит писать',
    'поругались',
  ];
  static final _negativeTriggerPatterns = negativeTriggers
      .map(_triggerPattern)
      .toList(growable: false);

  final ChatService _chatService;
  final SharedPreferences? preferences;
  final Random _random;
  final String assetPath;
  Future<SharedPreferences>? _preferencesFuture;

  Future<ChatSnippet> getRandomSnippet({int contextCount = 3}) async {
    final export = await _chatService.loadExport();
    final messageAuthors = List<String?>.filled(export.messages.length, null);
    final participants = <String>{};
    for (var index = 0; index < export.messages.length; index++) {
      final message = export.messages[index];
      final authorKey = _participantKey(message);
      messageAuthors[index] = authorKey;
      if (message.type == 'message' && authorKey != null) {
        participants.add(authorKey);
      }
    }
    if (participants.length != 2) {
      throw const NoEligibleMemoryException();
    }

    final participantKeys = participants.toList(growable: false);
    final firstParticipant = participantKeys[0];
    final secondParticipant = participantKeys[1];
    final usableRows = List<bool>.filled(export.messages.length, false);
    for (var index = 0; index < export.messages.length; index++) {
      final message = export.messages[index];
      final authorKey = messageAuthors[index];
      usableRows[index] =
          message.type == 'message' &&
          message.action == null &&
          message.text.trim().isNotEmpty &&
          (authorKey == firstParticipant || authorKey == secondParticipant) &&
          !_containsNegativeTrigger(message.text);
    }

    List<_IndexedMessage>? selectedWindow;
    var eligibleWindowCount = 0;
    for (var start = 0; start < export.messages.length; start++) {
      for (var size = 6; size <= 10; size++) {
        final end = start + size;
        if (end > export.messages.length) break;
        var firstParticipantCount = 0;
        var secondParticipantCount = 0;
        var eligible = true;
        for (var index = start; index < end; index++) {
          if (!usableRows[index]) {
            eligible = false;
            break;
          }
          final authorKey = messageAuthors[index]!;
          if (authorKey == firstParticipant) {
            firstParticipantCount++;
          } else {
            secondParticipantCount++;
          }
        }
        if (eligible &&
            firstParticipantCount >= 3 &&
            secondParticipantCount >= 3) {
          eligibleWindowCount++;
          if (_random.nextInt(eligibleWindowCount) == 0) {
            selectedWindow = List.generate(
              size,
              (offset) => _IndexedMessage(
                start + offset,
                export.messages[start + offset],
              ),
              growable: false,
            );
          }
        }
      }
    }
    final window = selectedWindow;
    if (window == null) {
      throw const NoEligibleMemoryException();
    }

    final messages = window
        .map((entry) {
          final message = entry.message;
          final authorName = message.from?.name.trim().isNotEmpty == true
              ? message.from!.name.trim()
              : (message.fromId ?? message.from?.id ?? 'Неизвестно');
          final messageId = message.id == null
              ? 'index-${entry.index}-${_stableHash('$authorName\u0000${message.text}')}'
              : 'id-${message.id}';
          return SnippetMessage(
            id: messageId,
            author: authorName,
            text: message.text,
            timestamp: message.date,
          );
        })
        .toList(growable: false);
    final chatIdentity = export.id == null
        ? _stableHash(export.name)
        : export.id.toString();
    return ChatSnippet(
      id: 'chat-$chatIdentity:${messages.map((message) => message.id).join(':')}',
      messages: messages,
    );
  }

  static String? _participantKey(Message message) {
    final id = message.fromId?.trim();
    final nestedId = message.from?.id?.trim();
    final participantId = id != null && id.isNotEmpty
        ? id
        : nestedId != null && nestedId.isNotEmpty
        ? nestedId
        : null;
    if (participantId != null) return 'id:$participantId';
    final name = message.from?.name.trim();
    return name == null || name.isEmpty ? null : 'name:${name.toLowerCase()}';
  }

  static bool _containsNegativeTrigger(String text) {
    final normalized = text.toLowerCase();
    return _negativeTriggerPatterns.any(
      (pattern) => pattern.hasMatch(normalized),
    );
  }

  static RegExp _triggerPattern(String trigger) {
    final escaped = trigger
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map(RegExp.escape)
        .join(r'\s+');
    return RegExp(
      '(^|[^A-Za-zА-Яа-яЁё0-9_])$escaped(\$|[^A-Za-zА-Яа-яЁё0-9_])',
    );
  }

  Future<List<ChatSnippet>> getFavorites() async {
    final stored = (await _getPreferences()).getString(favoritesKey);
    if (stored == null || stored.isEmpty) return const [];
    final decoded = jsonDecode(stored);
    if (decoded is! List) {
      throw const FormatException('Saved Telegram favorites must be a list.');
    }
    return List.unmodifiable(
      decoded.map((item) {
        if (item is! Map) {
          throw const FormatException(
            'Saved Telegram favorite must be an object.',
          );
        }
        return ChatSnippet.fromJson(Map<String, dynamic>.from(item));
      }),
    );
  }

  Future<bool> isFavorite(ChatSnippet snippet) async {
    final favorites = await getFavorites();
    return favorites.any((favorite) => favorite.id == snippet.id);
  }

  Future<bool> toggleFavorite(ChatSnippet snippet) async {
    final preferences = await _getPreferences();
    final favorites = List<ChatSnippet>.of(await getFavorites());
    final existingIndex = favorites.indexWhere(
      (favorite) => favorite.id == snippet.id,
    );
    if (existingIndex >= 0) {
      favorites.removeAt(existingIndex);
    } else {
      favorites.add(snippet);
    }
    final saved = await preferences.setString(
      favoritesKey,
      jsonEncode(favorites.map((favorite) => favorite.toJson()).toList()),
    );
    if (!saved) throw StateError('Unable to persist Telegram favorites.');
    return existingIndex < 0;
  }

  Future<SharedPreferences> _getPreferences() {
    if (preferences != null) return Future.value(preferences);
    return _preferencesFuture ??= SharedPreferences.getInstance();
  }

  static String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }
}

class _IndexedMessage {
  const _IndexedMessage(this.index, this.message);

  final int index;
  final Message message;
}
