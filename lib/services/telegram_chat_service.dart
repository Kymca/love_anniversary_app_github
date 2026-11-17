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
  static const dailySnippetKey = 'telegram_chat_daily_snippet';
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
    return _createSnippet(export, _random, contextCount: contextCount);
  }

  Future<ChatSnippet> getDailySnippet({
    DateTime? date,
    int contextCount = 3,
  }) async {
    final export = await _chatService.loadExport();
    final localDate = (date ?? DateTime.now()).toLocal();
    final dayKey =
        '${localDate.year.toString().padLeft(4, '0')}-'
        '${localDate.month.toString().padLeft(2, '0')}-'
        '${localDate.day.toString().padLeft(2, '0')}';
    final preferences = await _getPreferences();
    final saved = preferences.getString(dailySnippetKey);
    String? previousSnippetId;
    final identity = export.id?.toString() ?? _stableHash(export.name);
    final exportFingerprint =
        'balanced-window-v1:$identity:${export.messages.length}:'
        '${export.lastMessageDate?.toUtc().toIso8601String() ?? 'none'}';
    var hasValidSavedCache = false;
    if (saved != null && saved.isNotEmpty) {
      try {
        final decoded = jsonDecode(saved);
        if (decoded is Map<String, dynamic> &&
            decoded['exportFingerprint'] == exportFingerprint &&
            decoded['date'] is String &&
            decoded['snippet'] is Map) {
          final cached = ChatSnippet.fromJson(
            Map<String, dynamic>.from(decoded['snippet'] as Map),
          );
          hasValidSavedCache = true;
          if (decoded['date'] == dayKey) return cached;
          previousSnippetId = cached.id;
        }
      } on FormatException {
        // A corrupt saved quote is disposable; rebuild it from the bundled export.
      } on TypeError {
        // A quote saved by an older app version may have an incompatible shape.
      }
      if (!hasValidSavedCache) await preferences.remove(dailySnippetKey);
    }

    final seed = int.parse(_stableHash('$identity:$dayKey'), radix: 16);
    ChatSnippet snippet;
    try {
      snippet = _createSnippet(
        export,
        Random(seed),
        contextCount: contextCount,
        excludedSnippetId: previousSnippetId,
      );
    } on NoEligibleMemoryException {
      if (previousSnippetId == null) rethrow;
      snippet = _createSnippet(
        export,
        Random(seed),
        contextCount: contextCount,
      );
    }
    final didSave = await preferences.setString(
      dailySnippetKey,
      jsonEncode({
        'date': dayKey,
        'exportFingerprint': exportFingerprint,
        'snippet': snippet.toJson(),
      }),
    );
    if (!didSave) throw StateError('Unable to persist daily Telegram snippet.');
    return snippet;
  }

  ChatSnippet _createSnippet(
    ChatExport export,
    Random random, {
    required int contextCount,
    String? excludedSnippetId,
  }) {
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
    final minimumParticipantMessages = max(3, contextCount);
    final invalidPrefix = List<int>.filled(export.messages.length + 1, 0);
    final firstParticipantPrefix = List<int>.filled(
      export.messages.length + 1,
      0,
    );
    final secondParticipantPrefix = List<int>.filled(
      export.messages.length + 1,
      0,
    );
    for (var index = 0; index < export.messages.length; index++) {
      final message = export.messages[index];
      final authorKey = messageAuthors[index];
      final isUsable =
          message.type == 'message' &&
          message.action == null &&
          message.text.trim().isNotEmpty &&
          (authorKey == firstParticipant || authorKey == secondParticipant) &&
          !_containsNegativeTrigger(message.text);
      invalidPrefix[index + 1] = invalidPrefix[index] + (isUsable ? 0 : 1);
      firstParticipantPrefix[index + 1] =
          firstParticipantPrefix[index] +
          (isUsable && authorKey == firstParticipant ? 1 : 0);
      secondParticipantPrefix[index + 1] =
          secondParticipantPrefix[index] +
          (isUsable && authorKey == secondParticipant ? 1 : 0);
    }

    List<_IndexedMessage>? selectedWindow;
    var eligibleWindowCount = 0;
    for (var start = 0; start < export.messages.length; start++) {
      for (var size = 6; size <= 10; size++) {
        final end = start + size;
        if (end > export.messages.length) break;
        final eligible = invalidPrefix[end] == invalidPrefix[start];
        final firstParticipantCount =
            firstParticipantPrefix[end] - firstParticipantPrefix[start];
        final secondParticipantCount =
            secondParticipantPrefix[end] - secondParticipantPrefix[start];
        if (eligible &&
            firstParticipantCount >= minimumParticipantMessages &&
            secondParticipantCount >= minimumParticipantMessages) {
          if (excludedSnippetId != null &&
              _snippetId(export, start, size) == excludedSnippetId) {
            continue;
          }
          eligibleWindowCount++;
          if (random.nextInt(eligibleWindowCount) == 0) {
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
    return ChatSnippet(
      id: _snippetId(export, window.first.index, window.length),
      messages: messages,
    );
  }

  String _snippetId(ChatExport export, int start, int size) {
    final chatIdentity = export.id == null
        ? _stableHash(export.name)
        : export.id.toString();
    final messageIds = <String>[];
    for (var index = start; index < start + size; index++) {
      final message = export.messages[index];
      final authorName = message.from?.name.trim().isNotEmpty == true
          ? message.from!.name.trim()
          : (message.fromId ?? message.from?.id ?? 'Неизвестно');
      messageIds.add(
        message.id == null
            ? 'index-$index-${_stableHash('$authorName\u0000${message.text}')}'
            : 'id-${message.id}',
      );
    }
    return 'chat-$chatIdentity:${messageIds.join(':')}';
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
