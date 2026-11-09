import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory_media.dart';

class MemoryMediaService {
  MemoryMediaService({
    this._preferences,
    Future<Directory> Function()? directoryProvider,
    DateTime Function()? clock,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
       _clock = clock ?? DateTime.now;

  static const storageKey = 'memories_media_v1';

  SharedPreferences? _preferences;
  final Future<Directory> Function() _directoryProvider;
  final DateTime Function() _clock;

  Future<List<MemoryMedia>> load() async {
    final raw = (await _getPreferences()).getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved memories must be a list.');
    }

    final items = <MemoryMedia>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        items.add(MemoryMedia.fromJson(entry));
      } on FormatException {
        continue;
      }
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(items);
  }

  Future<MemoryMedia> addFile({
    required String sourcePath,
    required MemoryMediaType type,
    required String caption,
  }) async {
    final now = _clock();
    final id = '${now.microsecondsSinceEpoch}_${type.name}';
    final storedFilePath = await copyFileToCollection(
      sourcePath,
      collection: 'memories',
      id: id,
    );

    final media = MemoryMedia(
      id: id,
      type: type,
      filePath: storedFilePath,
      caption: caption.trim(),
      timestamp: now,
    );
    final items = [...await load(), media]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _save(items);
    return media;
  }

  Future<String> copyFileToCollection(
    String sourcePath, {
    required String collection,
    required String id,
  }) async {
    if (!_isSafePathSegment(collection) || !_isSafePathSegment(id)) {
      throw ArgumentError('Collection and id must be simple path segments.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Выбранный файл не найден.', sourcePath);
    }

    final directory = await _directoryProvider();
    final mediaDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}$collection',
    );
    await mediaDirectory.create(recursive: true);
    final destination = File(
      '${mediaDirectory.path}${Platform.pathSeparator}$id'
      '${_extension(sourcePath)}',
    );
    await source.copy(destination.path);
    return destination.path;
  }

  Future<void> addAsset({
    required String assetPath,
    required MemoryMediaType type,
    required String caption,
  }) async {
    final now = _clock();
    final media = MemoryMedia(
      id: '${now.microsecondsSinceEpoch}_${type.name}',
      type: type,
      filePath: assetPath.startsWith('asset:') ? assetPath : 'asset:$assetPath',
      caption: caption.trim(),
      timestamp: now,
    );
    final items = [...await load(), media]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _save(items);
  }

  Future<void> remove(String id) async {
    final items = await load();
    final removed = items.where((item) => item.id == id).toList();
    await _save(items.where((item) => item.id != id).toList());
    for (final item in removed) {
      if (item.filePath.startsWith('asset:')) continue;
      final file = File(item.filePath);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _save(List<MemoryMedia> items) async {
    await (await _getPreferences()).setString(
      storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || path.substring(dot).contains(Platform.pathSeparator)) {
      return '';
    }
    return path.substring(dot);
  }

  bool _isSafePathSegment(String value) =>
      value.isNotEmpty &&
      value != '.' &&
      value != '..' &&
      !value.contains('/') &&
      !value.contains(r'\');
}
