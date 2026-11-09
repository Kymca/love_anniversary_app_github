import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class CinemaMovie {
  const CinemaMovie({
    required this.id,
    required this.title,
    this.watched = false,
    this.votes = const {},
  });

  final String id;
  final String title;
  final bool watched;
  final Map<String, bool> votes;

  bool get matched => votes.length == 2 && votes.values.every((vote) => vote);

  CinemaMovie copyWith({bool? watched, Map<String, bool>? votes}) =>
      CinemaMovie(
        id: id,
        title: title,
        watched: watched ?? this.watched,
        votes: votes ?? this.votes,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'watched': watched,
    'votes': votes,
  };

  factory CinemaMovie.fromJson(Map<String, dynamic> json) => CinemaMovie(
    id: json['id'] as String,
    title: json['title'] as String,
    watched: json['watched'] as bool? ?? false,
    votes: {
      for (final entry in (json['votes'] as Map? ?? {}).entries)
        if (entry.value is bool) entry.key as String: entry.value as bool,
    },
  );
}

abstract interface class CinemaNightRepository {
  Future<List<CinemaMovie>> load();

  Future<void> add(String title);

  Future<void> markWatched(String id);

  Future<void> vote(String id, String participant, bool likes);
}

class SharedPreferencesCinemaNightRepository implements CinemaNightRepository {
  SharedPreferencesCinemaNightRepository({this.preferences, Random? random})
    : _random = random ?? Random();

  static const storageKey = 'cinema_night_movies_v1';
  static const initialPool = [
    'Вверх',
    'Рататуй',
    'Паддингтон',
    'Как приручить дракона',
    'Тайна Коко',
    'Амели',
    'Зверополис',
    'Мой сосед Тоторо',
    'Лука',
    'Шрэк',
    'Клаус',
  ];

  final SharedPreferences? preferences;
  final Random _random;

  @override
  Future<List<CinemaMovie>> load() async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Saved movie list must be a list.');
      }
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) CinemaMovie.fromJson(item),
      ];
    }
    final pool = List<String>.from(initialPool)..shuffle(_random);
    final movies = [
      for (final title in pool.take(5))
        CinemaMovie(
          id: '${DateTime.now().microsecondsSinceEpoch}-${moviesId++}',
          title: title,
        ),
    ];
    await _save(movies);
    return movies;
  }

  static int moviesId = 0;

  @override
  Future<void> add(String title) async {
    final clean = title.trim();
    if (clean.isEmpty) throw ArgumentError.value(title, 'title');
    final movies = [...await load()];
    if (movies.any(
      (movie) => movie.title.toLowerCase() == clean.toLowerCase(),
    )) {
      return;
    }
    movies.add(
      CinemaMovie(
        id: '${DateTime.now().microsecondsSinceEpoch}-${movies.length}',
        title: clean,
      ),
    );
    await _save(movies);
  }

  @override
  Future<void> markWatched(String id) async {
    final movies = [...await load()];
    final index = movies.indexWhere((movie) => movie.id == id);
    if (index < 0) throw StateError('Movie not found.');
    movies[index] = movies[index].copyWith(watched: true);
    await _save(movies);
  }

  @override
  Future<void> vote(String id, String participant, bool likes) async {
    if (participant != 'Алина' && participant != 'Партнёр') {
      throw ArgumentError.value(participant, 'participant');
    }
    final movies = [...await load()];
    final index = movies.indexWhere((movie) => movie.id == id);
    if (index < 0) throw StateError('Movie not found.');
    final movie = movies[index];
    if (movie.watched) return;
    movies[index] = movie.copyWith(votes: {...movie.votes, participant: likes});
    await _save(movies);
  }

  Future<void> _save(List<CinemaMovie> movies) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(movies.map((movie) => movie.toJson()).toList()),
    );
  }
}
