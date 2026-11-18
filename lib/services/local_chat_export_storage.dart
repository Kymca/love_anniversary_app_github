import 'chat_export_storage.dart';
import 'local_chat_export_storage_stub.dart'
    if (dart.library.io) 'local_chat_export_storage_io.dart'
    as implementation;

ChatExportStorage createLocalChatExportStorage() =>
    implementation.createLocalChatExportStorage();
