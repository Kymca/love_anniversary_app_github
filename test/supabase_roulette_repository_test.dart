import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:love_anniversary_app/services/roulette_repository.dart';
import 'package:love_anniversary_app/services/supabase_roulette_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'loads and filters shared exclusions for every roulette category',
    () async {
      final now = DateTime.now().toUtc();
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          expect(request.method, 'GET');
          expect(request.url.path, '/rest/v1/pair_roulette_exclusions');
          return http.Response(
            jsonEncode([
              {
                'choice_key': 'watched',
                'watched': true,
                'excluded_until': null,
              },
              {
                'choice_key': 'future',
                'watched': false,
                'excluded_until': now
                    .add(const Duration(days: 1))
                    .toIso8601String(),
              },
              {
                'choice_key': 'expired',
                'watched': false,
                'excluded_until': now
                    .subtract(const Duration(days: 1))
                    .toIso8601String(),
              },
              {
                'choice_key': 'no-expiry',
                'watched': false,
                'excluded_until': null,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );

      try {
        final repository = SupabaseRouletteRepository(
          client: client,
          activePairId: () async => 'pair-id',
        );

        for (final category in RouletteCategory.values) {
          final excluded = await repository.loadExcludedChoiceKeys(category);
          expect(
            excluded,
            category == RouletteCategory.movie
                ? ['watched', 'expired']
                : ['watched', 'future'],
          );
          expect(
            requests.last.url.queryParameters,
            containsPair('select', 'choice_key,watched,excluded_until'),
          );
          expect(requests.last.url.queryParameters['pair_id'], 'eq.pair-id');
          expect(
            requests.last.url.queryParameters['category'],
            'eq.${category.name}',
          );
        }

        expect(requests, hasLength(RouletteCategory.values.length));
        expect(
          requests.every(
            (request) =>
                !request.url.path.endsWith('/rpc/get_pair_roulette_exclusions'),
          ),
          isTrue,
        );
      } finally {
        await client.dispose();
      }
    },
  );

  test('does not request exclusions when there is no active pair', () async {
    var requests = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        requests++;
        return http.Response('[]', 200, request: request);
      }),
    );
    try {
      final repository = SupabaseRouletteRepository(
        client: client,
        activePairId: () async => null,
      );

      expect(
        await repository.loadExcludedChoiceKeys(RouletteCategory.food),
        isEmpty,
      );
      expect(
        await repository.startSpin(
          RouletteCategory.food,
          'Кафе',
          'builtin:food:2',
        ),
        isNotNull,
      );
      expect(requests, 0);
    } finally {
      await client.dispose();
    }
  });

  test('starts a pair-wide spin through the authorized RPC', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/rpc/start_pair_roulette_spin');
        return http.Response(
          jsonEncode({
            'spin_id': 'spin-id',
            'category': 'food',
            'choice_key': 'builtin:food:2',
            'choice': 'Кафе',
            'started_at': '2026-11-18T12:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    try {
      final repository = SupabaseRouletteRepository(
        client: client,
        activePairId: () async => 'pair-id',
      );

      final spin = await repository.startSpin(
        RouletteCategory.food,
        'Кафе',
        'builtin:food:2',
      );

      expect(spin?.id, 'spin-id');
      expect(spin?.category, RouletteCategory.food);
      expect(spin?.choice, 'Кафе');
      expect(spin?.choiceKey, 'builtin:food:2');
      expect(spin?.startedAt, DateTime.utc(2026, 11, 18, 12));
      expect(jsonDecode(requests.single.body), {
        'p_pair_id': 'pair-id',
        'p_category': 'food',
        'p_choice': 'Кафе',
        'p_choice_key': 'builtin:food:2',
      });
    } finally {
      await client.dispose();
    }
  });

  test('reports an active pair spin without starting another', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/start_pair_roulette_spin');
        return http.Response('null', 200, request: request);
      }),
    );
    try {
      final repository = SupabaseRouletteRepository(
        client: client,
        activePairId: () async => 'pair-id',
      );

      expect(
        await repository.startSpin(
          RouletteCategory.activity,
          'Прогулка',
          'builtin:activity:0',
        ),
        isNull,
      );
    } finally {
      await client.dispose();
    }
  });
}
