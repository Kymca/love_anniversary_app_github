class CountdownEvent {
  const CountdownEvent({
    required this.id,
    required this.title,
    required this.eventDate,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime eventDate;
  final DateTime createdAt;

  bool get hasPassed => !eventDate.isAfter(DateTime.now());

  double progressAt(DateTime now) {
    final total = eventDate.difference(createdAt).inMicroseconds;
    if (total <= 0 || !eventDate.isAfter(now)) return 1;
    if (!now.isAfter(createdAt)) return 0;
    return (now.difference(createdAt).inMicroseconds / total).clamp(0.0, 1.0);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'eventDate': eventDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory CountdownEvent.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    final eventDate = json['eventDate'];
    final createdAt = json['createdAt'];
    if (id is! String ||
        title is! String ||
        title.trim().isEmpty ||
        eventDate is! String ||
        createdAt is! String) {
      throw const FormatException('Invalid countdown event.');
    }
    final parsedEventDate = DateTime.tryParse(eventDate);
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    if (parsedEventDate == null || parsedCreatedAt == null) {
      throw const FormatException('Invalid countdown date.');
    }
    return CountdownEvent(
      id: id,
      title: title,
      eventDate: parsedEventDate,
      createdAt: parsedCreatedAt,
    );
  }
}
