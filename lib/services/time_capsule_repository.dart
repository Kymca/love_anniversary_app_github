import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/time_capsule.dart';
import 'memory_media_service.dart';

class TimeCapsuleRepository {
  TimeCapsuleRepository({
    this.preferences,
    required this._mediaService,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const storageKey = 'time_capsules_v1';

  final SharedPreferences? preferences;
  final MemoryMediaService _mediaService;
  final DateTime Function() _clock;

  Future<List<TimeCapsule>> load() async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved time capsules must be a list.');
    }
    final capsules = <TimeCapsule>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        capsules.add(TimeCapsule.fromJson(entry));
      } on FormatException {
        continue;
      }
    }
    capsules.sort((a, b) => a.unlockDate.compareTo(b.unlockDate));
    return List.unmodifiable(capsules);
  }

  Future<TimeCapsule> createText({
    required String note,
    required DateTime unlockDate,
  }) async {
    final text = note.trim();
    if (text.isEmpty) {
      throw ArgumentError.value(note, 'note', 'Must not be empty.');
    }
    return _create(unlockDate: unlockDate, note: text);
  }

  Future<TimeCapsule> createPhoto({
    required String sourcePath,
    required DateTime unlockDate,
    String? note,
  }) async {
    _validateUnlockDate(unlockDate);
    final id = _newId();
    final storedPath = await _mediaService.copyFileToCollection(
      sourcePath,
      collection: 'time_capsules',
      id: id,
    );
    return _create(
      unlockDate: unlockDate,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      photoPath: storedPath,
      id: id,
    );
  }

  Future<TimeCapsule> _create({
    required DateTime unlockDate,
    String? note,
    String? photoPath,
    String? id,
  }) async {
    _validateUnlockDate(unlockDate);
    final capsule = TimeCapsule(
      id: id ?? _newId(),
      unlockDate: DateTime(unlockDate.year, unlockDate.month, unlockDate.day),
      createdAt: _clock(),
      note: note,
      photoPath: photoPath,
    );
    final capsules = [...await load(), capsule]
      ..sort((a, b) => a.unlockDate.compareTo(b.unlockDate));
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(capsules.map((item) => item.toJson()).toList()),
    );
    return capsule;
  }

  Future<void> remove(String id) async {
    final capsules = await load();
    final removed = capsules.where((capsule) => capsule.id == id);
    final remaining = capsules.where((capsule) => capsule.id != id).toList();
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(remaining.map((item) => item.toJson()).toList()),
    );
    for (final capsule in removed) {
      final path = capsule.photoPath;
      if (path == null) continue;
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  void _validateUnlockDate(DateTime unlockDate) {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final unlockDay = DateTime(
      unlockDate.year,
      unlockDate.month,
      unlockDate.day,
    );
    if (!unlockDay.isAfter(today)) {
      throw ArgumentError.value(
        unlockDate,
        'unlockDate',
        'Дата открытия должна быть в будущем.',
      );
    }
  }

  String _newId() {
    final time = _clock().microsecondsSinceEpoch;
    return '${time}_${DateTime.now().microsecondsSinceEpoch}';
  }
}
