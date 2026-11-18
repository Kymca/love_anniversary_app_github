import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/chat_export.dart';
import 'chat_export_storage.dart';
import 'local_chat_export_storage.dart';

class ChatExportUnavailableException implements Exception {
  const ChatExportUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'ChatExportUnavailableException: $cause';
}

class ChatService {
  ChatService({
    AssetBundle? bundle,
    this.assetPath = 'result.json',
    ChatExportStorage? localExportStorage,
  }) : _bundle = bundle ?? rootBundle,
       _localExportStorage =
           localExportStorage ??
           (bundle == null ? createLocalChatExportStorage() : null);

  final AssetBundle _bundle;
  final String assetPath;
  final ChatExportStorage? _localExportStorage;
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
      final source = await _loadSource();
      return await _decodeSourceAsync(source);
    } on Object catch (error) {
      throw ChatExportUnavailableException(error);
    }
  }

  Future<String> _loadSource() async {
    final localExport = await _localExportStorage?.read();
    if (localExport != null) return localExport;
    return _bundle.loadString(assetPath);
  }

  Future<void> importLocalExport(Stream<List<int>> bytes) async {
    final storage = _localExportStorage;
    if (storage == null) {
      throw StateError('Local Telegram export storage is unavailable.');
    }
    final export = await storage.importExport(bytes, _decodeSourceAsync);
    _exportFuture = Future.value(export);
  }

  Future<ChatExport> _decodeSourceAsync(String source) async {
    final decoded = source.length > 100000
        ? await compute(_decodeExportJson, source)
        : _decodeExportJson(source);
    return ChatExport.fromJson(Map<String, dynamic>.from(decoded));
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
