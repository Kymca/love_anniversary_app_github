enum PostcardDirection { sent, received }

class Postcard {
  const Postcard({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.direction,
    required this.peerName,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  final PostcardDirection direction;
  final String peerName;

  Map<String, Object?> toJson() => {
    'id': id,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'direction': direction.name,
    'peerName': peerName,
  };

  static Postcard fromJson(Map<String, dynamic> json) {
    final direction = PostcardDirection.values.firstWhere(
      (value) => value.name == json['direction'],
    );
    return Postcard(
      id: json['id'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      direction: direction,
      peerName: json['peerName'] as String,
    );
  }
}
