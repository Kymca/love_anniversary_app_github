import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/chat_export.dart';

class ChatExportUnavailableException implements Exception {
  const ChatExportUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'ChatExportUnavailableException: $cause';
}

class ChatService {
  ChatService({AssetBundle? bundle, this.assetPath = 'result.json'})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;
  Future<ChatExport>? _exportFuture;

  Future<ChatExport> loadExport() async {
    final cached = _exportFuture;
    if (cached != null) return cached;
    final pending = _loadExport();
    _exportFuture = pending;
    try {
      return await pending;
    } on Object {
      if (identical(_exportFuture, pending)) _exportFuture = null;
      rethrow;
    }
  }

  Future<ChatExport> _loadExport() async {
    try {
      final source = await _bundle.loadString(assetPath);
      final decoded = source.length > 100000
          ? await compute(_decodeExportJson, source)
          : _decodeExportJson(source);
      return ChatExport.fromJson(Map<String, dynamic>.from(decoded));
    } on Object catch (error) {
      throw ChatExportUnavailableException(error);
    }
  }

  Future<List<Message>> getMessages() async => (await loadExport()).messages;

  Future<DateTime?> getFirstMessageDate() async =>
      (await loadExport()).firstMessageDate;

  Future<DateTime?> getLastMessageDate() async =>
      (await loadExport()).lastMessageDate;

  Future<Map<String, int>> getMessageCountsByParticipant() async =>
      (await loadExport()).messageCountsByParticipant;
}

Map<String, dynamic> _decodeExportJson(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Telegram export root must be a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}
