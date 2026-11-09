enum MemoryMediaType { photo, video }

class MemoryMedia {
  const MemoryMedia({
    required this.id,
    required this.type,
    required this.filePath,
    required this.caption,
    required this.timestamp,
  });

  final String id;
  final MemoryMediaType type;
  final String filePath;
  final String caption;
  final DateTime timestamp;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'filePath': filePath,
    'caption': caption,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MemoryMedia.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final type = json['type'];
    final filePath = json['filePath'];
    final caption = json['caption'];
    final timestamp = json['timestamp'];
    if (id is! String ||
        (type != 'photo' && type != 'video') ||
        filePath is! String ||
        caption is! String ||
        timestamp is! String) {
      throw const FormatException('Invalid memory media record.');
    }

    final parsedTimestamp = DateTime.tryParse(timestamp);
    if (parsedTimestamp == null) {
      throw const FormatException('Invalid memory media timestamp.');
    }

    return MemoryMedia(
      id: id,
      type: MemoryMediaType.values.byName(type as String),
      filePath: filePath,
      caption: caption,
      timestamp: parsedTimestamp,
    );
  }
}
