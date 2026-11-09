class PairMember {
  const PairMember({required this.name});

  final String name;

  Map<String, Object?> toJson() => {'name': name};

  factory PairMember.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid pair member.');
    }
    return PairMember(name: name);
  }
}

class PairRoom {
  const PairRoom({required this.code, required this.members});

  final String code;
  final List<PairMember> members;

  Map<String, Object?> toJson() => {
    'code': code,
    'members': members.map((member) => member.toJson()).toList(),
  };

  factory PairRoom.fromJson(Map<String, Object?> json) {
    final code = json['code'];
    final members = json['members'];
    if (code is! String ||
        !RegExp(r'^\d{4}$').hasMatch(code) ||
        members is! List) {
      throw const FormatException('Invalid pair room.');
    }
    final parsed = <PairMember>[];
    for (final member in members) {
      if (member is! Map<String, dynamic>) {
        throw const FormatException('Invalid pair member list.');
      }
      parsed.add(PairMember.fromJson(member));
    }
    return PairRoom(code: code, members: List.unmodifiable(parsed));
  }
}
