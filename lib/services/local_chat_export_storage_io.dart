import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/chat_export.dart';
import 'chat_export_storage.dart';

class _LocalChatExportStorage implements ChatExportStorage {
  static const _fileName = 'telegram_export.json';

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<ChatExport> importExport(
    Stream<List<int>> bytes,
    Future<ChatExport> Function(String source) decode,
  ) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporaryFile = File('${file.path}.importing');
    final backupFile = File('${file.path}.backup');
    try {
      final sink = temporaryFile.openWrite();
      try {
        await sink.addStream(bytes);
        await sink.flush();
      } finally {
        await sink.close();
      }
      final export = await decode(await temporaryFile.readAsString());
      if (await backupFile.exists()) await backupFile.delete();
      final hadPreviousExport = await file.exists();
      if (hadPreviousExport) await file.rename(backupFile.path);
      try {
        await temporaryFile.rename(file.path);
      } on Object {
        if (hadPreviousExport && await backupFile.exists()) {
          await backupFile.rename(file.path);
        }
        rethrow;
      }
      if (hadPreviousExport && await backupFile.exists()) {
        await backupFile.delete();
      }
      return export;
    } on Object {
      if (await temporaryFile.exists()) await temporaryFile.delete();
      rethrow;
    }
  }
}

ChatExportStorage createLocalChatExportStorage() => _LocalChatExportStorage();
