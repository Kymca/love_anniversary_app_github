class TimeCapsule {
  const TimeCapsule({
    required this.id,
    required this.unlockDate,
    required this.createdAt,
    this.note,
    this.photoPath,
  });

  final String id;
  final DateTime unlockDate;
  final DateTime createdAt;
  final String? note;
  final String? photoPath;

  bool get hasContent =>
      (note?.trim().isNotEmpty ?? false) || photoPath != null;

  bool isUnlockedAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final unlockDay = DateTime(
      unlockDate.year,
      unlockDate.month,
      unlockDate.day,
    );
    return !today.isBefore(unlockDay);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'unlockDate': DateTime(
      unlockDate.year,
      unlockDate.month,
      unlockDate.day,
    ).toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'note': note,
    'photoPath': photoPath,
  };

  factory TimeCapsule.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final unlockDate = json['unlockDate'];
    final createdAt = json['createdAt'];
    final note = json['note'];
    final photoPath = json['photoPath'];
    if (id is! String ||
        unlockDate is! String ||
        createdAt is! String ||
        (note != null && note is! String) ||
        (photoPath != null && photoPath is! String)) {
      throw const FormatException('Invalid time capsule record.');
    }
    final parsedUnlockDate = DateTime.tryParse(unlockDate);
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    if (parsedUnlockDate == null || parsedCreatedAt == null) {
      throw const FormatException('Invalid time capsule date.');
    }
    final capsule = TimeCapsule(
      id: id,
      unlockDate: parsedUnlockDate,
      createdAt: parsedCreatedAt,
      note: note as String?,
      photoPath: photoPath as String?,
    );
    if (!capsule.hasContent) {
      throw const FormatException('Time capsule has no content.');
    }
    return capsule;
  }
}
