import 'dart:math' as math;

class DailyCinemaFilm {
  const DailyCinemaFilm({
    required this.id,
    required this.titleRu,
    required this.titleUk,
  });

  final String id;
  final String titleRu;
  final String titleUk;

  String titleFor(String languageCode) =>
      languageCode == 'uk' ? titleUk : titleRu;
}

class DailyCinemaLineup {
  const DailyCinemaLineup({
    required this.localDate,
    required this.movies,
    required this.winnerIndex,
  });

  final String localDate;
  final List<DailyCinemaFilm> movies;
  final int winnerIndex;

  DailyCinemaFilm get winner => movies[winnerIndex];
}

double dailyCinemaRotationForWinner(
  int winnerIndex, {
  int filmCount = 5,
  int fullRotations = 5,
}) {
  final slice = math.pi * 2 / filmCount;
  final winnerCenter = (winnerIndex + 0.5) * slice;
  return fullRotations * math.pi * 2 + (math.pi * 2 - winnerCenter);
}

int dailyCinemaWinnerAtPointer(double rotationRadians, {int filmCount = 5}) {
  final slice = math.pi * 2 / filmCount;
  final normalized =
      (-rotationRadians % (math.pi * 2) + math.pi * 2) % (math.pi * 2);
  return (normalized / slice).floor() % filmCount;
}

const dailyCinemaCatalog = <DailyCinemaFilm>[
  DailyCinemaFilm(id: 'ratatouille', titleRu: 'Рататуй', titleUk: 'Рататуй'),
  DailyCinemaFilm(id: 'up', titleRu: 'Вверх', titleUk: 'Вперед і вгору'),
  DailyCinemaFilm(
    id: 'paddington',
    titleRu: 'Приключения Паддингтона',
    titleUk: 'Пригоди Паддінгтона',
  ),
  DailyCinemaFilm(id: 'coco', titleRu: 'Тайна Коко', titleUk: 'Таємниця Коко'),
  DailyCinemaFilm(id: 'amelie', titleRu: 'Амели', titleUk: 'Амелі'),
  DailyCinemaFilm(
    id: 'totoro',
    titleRu: 'Мой сосед Тоторо',
    titleUk: 'Мій сусід Тоторо',
  ),
  DailyCinemaFilm(id: 'luca', titleRu: 'Лука', titleUk: 'Лука'),
  DailyCinemaFilm(id: 'shrek', titleRu: 'Шрэк', titleUk: 'Шрек'),
  DailyCinemaFilm(id: 'klaus', titleRu: 'Клаус', titleUk: 'Клаус'),
  DailyCinemaFilm(
    id: 'zootopia',
    titleRu: 'Зверополис',
    titleUk: 'Зоотрополіс',
  ),
  DailyCinemaFilm(
    id: 'dragon',
    titleRu: 'Как приручить дракона',
    titleUk: 'Як приборкати дракона',
  ),
  DailyCinemaFilm(
    id: 'little-prince',
    titleRu: 'Маленький принц',
    titleUk: 'Маленький принц',
  ),
];

DailyCinemaLineup dailyCinemaLineup(
  DateTime instant, {
  List<DailyCinemaFilm> candidates = dailyCinemaCatalog,
  math.Random? random,
}) {
  final local = instant.toLocal();
  final date =
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final source = random ?? math.Random();
  final shuffled = List<DailyCinemaFilm>.from(candidates)..shuffle(source);
  final movies = List<DailyCinemaFilm>.unmodifiable(
    shuffled.take(math.min(5, shuffled.length)),
  );
  return DailyCinemaLineup(
    localDate: date,
    movies: movies,
    winnerIndex: movies.isEmpty ? -1 : source.nextInt(movies.length),
  );
}
