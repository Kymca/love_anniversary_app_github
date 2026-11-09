enum DailyMood {
  joyful('😄', 'Радостно', [
    'Сохрани этот яркий момент — пусть утка тоже порадуется вместе с тобой.',
    'Твоя улыбка сегодня заразительна. Подари её кому-нибудь рядом.',
    'Какой чудесный день! Устрой маленький праздник из обычного момента.',
  ]),
  calm('🙂', 'Спокойно', [
    'Тихие дни тоже прекрасны. Можно просто побыть в своём ритме.',
    'Уточка напоминает: не обязательно торопиться, чтобы всё успеть.',
    'Пусть сегодня будет побольше уютных пауз и любимого чая.',
  ]),
  thoughtful('😐', 'Обычно', [
    'Обычный день — отличная возможность заметить что-то хорошее вокруг.',
    'Добавь в день одну маленькую радость — уточка одобряет.',
    'Даже спокойный день может спрятать приятный сюрприз.',
  ]),
  tired('😴', 'Устала', [
    'Уточка советует устроить себе уютную передышку, если получится.',
    'Сегодня можно выбрать самый мягкий темп и поберечь силы.',
    'Плед, вода и немного тишины — утка шлёт тебе поддержку.',
  ]),
  blue('🥺', 'Грустно', [
    'Уточка рядом и желает тебе чего-нибудь тёплого и доброго.',
    'Пусть сегодня найдётся хотя бы один маленький повод улыбнуться.',
    'Ты не обязана быть весёлой каждую минуту. Уточка просто посидит рядом.',
  ]),
  angry('😠', 'Злюсь', [
    'Злиться можно. Уточка рядом и поможет спокойно перевести дух.',
    'Пусть гнев немного утихнет, а рядом найдётся место для твоих чувств.',
    'Уточка сердито топает лапкой вместе с тобой, а потом предлагает чай.',
  ]);

  const DailyMood(this.emoji, this.label, this.compliments);

  final String emoji;
  final String label;
  final List<String> compliments;

  String complimentFor(String dateKey) {
    final dayNumber = int.parse(dateKey.substring(dateKey.length - 2));
    return compliments[dayNumber % compliments.length];
  }
}

class DailyMoodEntry {
  const DailyMoodEntry({
    required this.dateKey,
    required this.mood,
    required this.compliment,
  });

  final String dateKey;
  final DailyMood mood;
  final String compliment;

  Map<String, Object?> toJson() => {
    'date': dateKey,
    'mood': mood.name,
    'compliment': compliment,
  };

  factory DailyMoodEntry.fromJson(Map<String, Object?> json) {
    final date = json['date'];
    final mood = json['mood'];
    final compliment = json['compliment'];
    if (date is! String ||
        mood is! String ||
        compliment is! String ||
        DateTime.tryParse(date) == null) {
      throw const FormatException('Invalid daily mood entry.');
    }
    final parsedMood = DailyMood.values.where((value) => value.name == mood);
    if (parsedMood.isEmpty) {
      throw const FormatException('Unknown daily mood.');
    }
    return DailyMoodEntry(
      dateKey: date,
      mood: parsedMood.first,
      compliment: compliment,
    );
  }
}

String moodDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
