import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:love_anniversary_app/services/movie_catalog_search.dart';

void main() {
  test(
    'TMDB search parses items and preserves paginated request params',
    () async {
      late Uri requestUri;
      final search = TmdbMovieCatalogSearch(
        apiKey: 'test-key',
        endpoint: 'https://tmdb.test/3/search/movie',
        client: MockClient((request) async {
          requestUri = request.url;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'page': 2,
                'total_pages': 8,
                'results': [
                  {'id': 42, 'title': 'Рататуй', 'release_date': '2007-06-22'},
                  {'id': 43, 'title': '', 'release_date': ''},
                ],
              }),
            ),
            200,
          );
        }),
      );

      final result = await search.search(' рататуй ', page: 2);

      expect(requestUri.queryParameters['api_key'], 'test-key');
      expect(requestUri.queryParameters['query'], 'рататуй');
      expect(requestUri.queryParameters['language'], 'ru-RU');
      expect(requestUri.queryParameters['page'], '2');
      expect(result.items, hasLength(1));
      expect(result.items.single.id, 'tmdb-42');
      expect(result.items.single.releaseYear, 2007);
      expect(result.hasMore, isTrue);
      expect(result.isOnlineCatalog, isTrue);
    },
  );

  test('TMDB errors are surfaced without echoing credentials', () async {
    final search = TmdbMovieCatalogSearch(
      apiKey: 'private-test-key',
      endpoint: 'https://tmdb.test/search',
      client: MockClient((_) async => http.Response('{}', 401)),
    );

    await expectLater(
      search.search('movie'),
      throwsA(
        isA<MovieCatalogException>().having(
          (error) => error.message,
          'message',
          contains('TMDB_API_KEY'),
        ),
      ),
    );
  });

  test('offline fallback searches its small local catalog', () async {
    const search = LocalMovieCatalogSearch();
    final results = await search.search('Рататуй');
    expect(search.isOnlineCatalog, isFalse);
    expect(results.items.map((item) => item.title), ['Рататуй']);
    expect(results.hasMore, isFalse);
  });
}
