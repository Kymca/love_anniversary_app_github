import 'dart:convert';

class From {
  const From({required this.name, this.id});

  final String name;
  final String? id;

  factory From.fromJson(Object? name, Object? id) {
    return From(name: name?.toString() ?? '', id: id?.toString());
  }
}

class TextEntity {
  const TextEntity({
    required this.text,
    this.type,
    this.extraFields = const {},
  });

  final String text;
  final String? type;
  final Map<String, dynamic> extraFields;

  factory TextEntity.fromJson(Object? json) {
    if (json is String) return TextEntity(text: json);
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      return TextEntity(
        text: _flattenText(map['text']),
        type: map['type']?.toString(),
        extraFields: Map.unmodifiable(
          Map<String, dynamic>.from(map)
            ..remove('text')
            ..remove('type'),
        ),
      );
    }
    return const TextEntity(text: '');
  }

  static String _flattenText(Object? value) {
    if (value is String) return value;
    if (value is List) {
      return value.map(_flattenText).join();
    }
    if (value is Map) {
      return _flattenText(value['text']);
    }
    return '';
  }
}

class Message {
  const Message({
    required this.id,
    required this.type,
    required this.date,
    this.from,
    this.actor,
    this.action,
    this.text = '',
    this.textEntities = const [],
    this.dateUnixtime,
    this.fromId,
    this.actorId,
    this.extraFields = const {},
  });

  final int? id;
  final String type;
  final DateTime? date;
  final int? dateUnixtime;
  final From? from;
  final String? fromId;
  final From? actor;
  final String? actorId;
  final String? action;
  final String text;
  final List<TextEntity> textEntities;
  final Map<String, dynamic> extraFields;

  bool get isService => type == 'service';

  factory Message.fromJson(Map<String, dynamic> json) {
    final dateUnixtime = _toInt(json['date_unixtime']);
    final dateValue = json['date']?.toString();
    final parsedDate = dateUnixtime != null
        ? DateTime.fromMillisecondsSinceEpoch(dateUnixtime * 1000, isUtc: true)
        : (dateValue == null ? null : DateTime.tryParse(dateValue));
    final rawText = json['text'];
    final rawEntities = rawText is List
        ? rawText
        : (rawText is String && rawText.isNotEmpty
              ? const []
              : json['text_entities']);
    final textEntities = rawEntities is List
        ? rawEntities.map(TextEntity.fromJson).toList(growable: false)
        : <TextEntity>[];
    final text = rawText is String && rawText.isNotEmpty
        ? rawText
        : textEntities.map((entity) => entity.text).join();

    const knownFields = {
      'id',
      'type',
      'date',
      'date_unixtime',
      'from',
      'from_id',
      'actor',
      'actor_id',
      'action',
      'text',
      'text_entities',
    };
    final extraFields = Map<String, dynamic>.from(json)
      ..removeWhere((key, _) => knownFields.contains(key));

    return Message(
      id: _toInt(json['id']),
      type: json['type']?.toString() ?? 'message',
      date: parsedDate,
      dateUnixtime: dateUnixtime,
      from: json['from'] == null && json['from_id'] == null
          ? null
          : From.fromJson(json['from'], json['from_id']),
      fromId: json['from_id']?.toString(),
      actor: json['actor'] == null && json['actor_id'] == null
          ? null
          : From.fromJson(json['actor'], json['actor_id']),
      actorId: json['actor_id']?.toString(),
      action: json['action']?.toString(),
      text: text,
      textEntities: List.unmodifiable(textEntities),
      extraFields: Map.unmodifiable(extraFields),
    );
  }

  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class ChatExport {
  const ChatExport({
    required this.name,
    required this.type,
    required this.messages,
    this.id,
    this.extraFields = const {},
  });

  final String name;
  final String type;
  final int? id;
  final List<Message> messages;
  final Map<String, dynamic> extraFields;

  factory ChatExport.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    if (rawMessages is! List) {
      throw const FormatException('Telegram export "messages" must be a list.');
    }
    const knownFields = {'name', 'type', 'id', 'messages'};
    final extraFields = Map<String, dynamic>.from(json)
      ..removeWhere((key, _) => knownFields.contains(key));
    return ChatExport(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      id: Message._toInt(json['id']),
      messages: List.unmodifiable(
        rawMessages.map((message) {
          if (message is! Map) {
            throw const FormatException(
              'Telegram export messages must be objects.',
            );
          }
          return Message.fromJson(Map<String, dynamic>.from(message));
        }),
      ),
      extraFields: Map.unmodifiable(extraFields),
    );
  }

  factory ChatExport.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'Telegram export root must be a JSON object.',
      );
    }
    return ChatExport.fromJson(Map<String, dynamic>.from(decoded));
  }

  DateTime? get firstMessageDate => _dateExtreme(first: true);
  DateTime? get lastMessageDate => _dateExtreme(first: false);

  DateTime? _dateExtreme({required bool first}) {
    final dates = messages.map((message) => message.date).whereType<DateTime>();
    if (dates.isEmpty) return null;
    return dates.reduce(
      (a, b) => first ? (a.isBefore(b) ? a : b) : (a.isAfter(b) ? a : b),
    );
  }

  Map<String, int> get messageCountsByParticipant {
    final counts = <String, int>{};
    for (final message in messages) {
      if (message.type != 'message' || message.from == null) continue;
      final name = message.from!.name;
      if (name.isEmpty) continue;
      counts.update(name, (count) => count + 1, ifAbsent: () => 1);
    }
    return Map.unmodifiable(counts);
  }
}
