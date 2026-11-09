import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class MovieSearchItem {
  const MovieSearchItem({
    required this.id,
    required this.title,
    this.releaseYear,
  });

  final String id;
  final String title;
  final int? releaseYear;
}

class MovieSearchPage {
  const MovieSearchPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.isOnlineCatalog,
  });

  final List<MovieSearchItem> items;
  final int page;
  final int totalPages;
  final bool isOnlineCatalog;

  bool get hasMore => page < totalPages;
}

abstract interface class MovieCatalogSearch {
  bool get isOnlineCatalog;

  Future<MovieSearchPage> search(String query, {int page = 1});
}

MovieCatalogSearch createMovieCatalogSearch({http.Client? client}) {
  const apiKey = String.fromEnvironment('TMDB_API_KEY');
  if (apiKey.trim().isEmpty) return LocalMovieCatalogSearch();
  return TmdbMovieCatalogSearch(apiKey: apiKey, client: client);
}

class LocalMovieCatalogSearch implements MovieCatalogSearch {
  const LocalMovieCatalogSearch();

  @override
  bool get isOnlineCatalog => false;

  @override
  Future<MovieSearchPage> search(String query, {int page = 1}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const MovieSearchPage(
        items: [],
        page: 1,
        totalPages: 1,
        isOnlineCatalog: false,
      );
    }
    final matches = [
      for (var index = 0; index < _localCatalog.length; index++)
        if (_localCatalog[index].toLowerCase().contains(normalized))
          MovieSearchItem(id: 'local-$index', title: _localCatalog[index]),
    ];
    return MovieSearchPage(
      items: page == 1 ? matches : const [],
      page: 1,
      totalPages: 1,
      isOnlineCatalog: false,
    );
  }
}

const _localCatalog = <String>[
  ...[
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
    'Король Лев',
    'Холодное сердце',
    'ВАЛЛ-И',
    'Душа',
    'Энканто',
    'История игрушек',
    'Головоломка',
    'Маленькая мисс Счастье',
    'Стажёр',
  ],
];

class TmdbMovieCatalogSearch implements MovieCatalogSearch {
  TmdbMovieCatalogSearch({
    required this.apiKey,
    http.Client? client,
    this.endpoint = 'https://api.themoviedb.org/3/search/movie',
  }) : _client = client ?? http.Client() {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'Must not be empty.');
    }
  }

  final String apiKey;
  final String endpoint;
  final http.Client _client;

  @override
  bool get isOnlineCatalog => true;

  @override
  Future<MovieSearchPage> search(String query, {int page = 1}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const MovieSearchPage(
        items: [],
        page: 1,
        totalPages: 1,
        isOnlineCatalog: true,
      );
    }
    if (page < 1) throw ArgumentError.value(page, 'page');

    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        'api_key': apiKey,
        'language': 'ru-RU',
        'include_adult': 'false',
        'query': cleanQuery,
        'page': '$page',
      },
    );
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const MovieCatalogException(
        'Не удалось подключиться к каталогу фильмов. Проверьте интернет.',
      );
    } on SocketException {
      throw const MovieCatalogException(
        'Не удалось подключиться к каталогу фильмов. Проверьте интернет.',
      );
    } on http.ClientException {
      throw const MovieCatalogException(
        'Не удалось подключиться к каталогу фильмов. Проверьте интернет.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MovieCatalogException(
        response.statusCode == 401 || response.statusCode == 403
            ? 'Каталог фильмов не принял API-ключ. Проверьте настройку TMDB_API_KEY.'
            : 'Каталог фильмов временно недоступен (HTTP ${response.statusCode}).',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['results'] is! List ||
          decoded['page'] is! int ||
          decoded['total_pages'] is! int) {
        throw const FormatException('Invalid TMDB response.');
      }
      final items = <MovieSearchItem>[];
      for (final result in decoded['results'] as List) {
        if (result is! Map<String, dynamic>) continue;
        final id = result['id'];
        final title = result['title'];
        if (id is! int || title is! String || title.trim().isEmpty) continue;
        final releaseDate = result['release_date'];
        final year = releaseDate is String && releaseDate.length >= 4
            ? int.tryParse(releaseDate.substring(0, 4))
            : null;
        items.add(
          MovieSearchItem(
            id: 'tmdb-$id',
            title: title.trim(),
            releaseYear: year,
          ),
        );
      }
      return MovieSearchPage(
        items: items,
        page: decoded['page'] as int,
        totalPages: decoded['total_pages'] as int,
        isOnlineCatalog: true,
      );
    } on FormatException {
      throw const MovieCatalogException(
        'Каталог фильмов вернул некорректный ответ.',
      );
    }
  }
}

class MovieCatalogException implements Exception {
  const MovieCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
