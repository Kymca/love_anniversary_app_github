import 'dart:async';

import '../models/chat_export.dart';
import 'chat_export_storage.dart';

class _LocalChatExportStorage implements ChatExportStorage {
  @override
  Future<String?> read() async => null;

  @override
  Future<ChatExport> importExport(
    Stream<List<int>> bytes,
    Future<ChatExport> Function(String source) decode,
  ) async {
    throw UnsupportedError('Local Telegram exports are unavailable here.');
  }
}

ChatExportStorage createLocalChatExportStorage() => _LocalChatExportStorage();
