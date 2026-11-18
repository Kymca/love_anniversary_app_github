import 'dart:async';

import '../models/chat_export.dart';

abstract interface class ChatExportStorage {
  Future<String?> read();

  Future<ChatExport> importExport(
    Stream<List<int>> bytes,
    Future<ChatExport> Function(String source) decode,
  );
}
