import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/services/daily_cinema.dart';
import 'package:love_anniversary_app/services/daily_cinema_repository.dart';
import 'package:love_anniversary_app/widgets/cinema_night_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

class _FixedRandom implements math.Random {
  const _FixedRandom(this.chooseMaximum);

  final bool chooseMaximum;

  @override
  int nextInt(int max) => chooseMaximum ? max - 1 : 0;

  @override
  bool nextBool() => chooseMaximum;

  @override
  double nextDouble() => chooseMaximum ? 0.999999 : 0;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('each randomized lineup chooses only an available film', () {
    final candidates = dailyCinemaCatalog.take(8).toList();
    final now = DateTime(2026, 11, 6, 15);
    final first = dailyCinemaLineup(
      now,
      candidates: candidates,
      random: const _FixedRandom(false),
    );
    final second = dailyCinemaLineup(
      now,
      candidates: candidates,
      random: const _FixedRandom(true),
    );

    expect(first.localDate, '2026-11-06');
    for (final lineup in [first, second]) {
      expect(lineup.movies, hasLength(5));
      expect(lineup.winnerIndex, inInclusiveRange(0, lineup.movies.length - 1));
      expect(candidates, contains(lineup.winner));
    }
    expect(second.winner.id, isNot(first.winner.id));
  });

  test('randomized lineup handles small and empty candidate lists', () {
    final one = dailyCinemaLineup(
      DateTime(2026, 11, 6),
      candidates: [dailyCinemaCatalog.first],
      random: const _FixedRandom(false),
    );
    final empty = dailyCinemaLineup(
      DateTime(2026, 11, 6),
      candidates: const [],
    );

    expect(one.movies, hasLength(1));
    expect(one.winner, dailyCinemaCatalog.first);
    expect(empty.movies, isEmpty);
    expect(empty.winnerIndex, -1);
  });

  test('wheel rotation puts any supported winner under the fixed pointer', () {
    for (var filmCount = 1; filmCount <= 5; filmCount++) {
      for (var index = 0; index < filmCount; index++) {
        expect(
          dailyCinemaWinnerAtPointer(
            dailyCinemaRotationForWinner(index, filmCount: filmCount),
            filmCount: filmCount,
          ),
          index,
        );
      }
    }
  });

  test(
    'custom films persist, and remove-for-today expires at local midnight',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesDailyCinemaRepository(
        preferences: preferences,
      );
      final today = DateTime(2026, 11, 6, 15);
      await repository.addCustomFilm('  Мой фильм  ');
      await repository.addCustomFilm('мой фильм');
      final custom = (await repository.loadAvailableFilms(today))
          .singleWhere((film) => film.id == 'custom:мой фильм');

      await repository.removeFilmForToday(custom.id, today);
      expect(
        (await repository.loadAvailableFilms(today))
            .any((film) => film.id == custom.id),
        isFalse,
      );
      expect(
        (await repository.loadAvailableFilms(DateTime(2026, 11, 7)))
            .any((film) => film.id == custom.id),
        isTrue,
      );
    },
  );

  test(
    'a skipped film returns exactly seven days after being skipped',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesDailyCinemaRepository(
        preferences: preferences,
      );
      final now = DateTime(2026, 11, 6, 15);
      final film = dailyCinemaCatalog.first;
      await repository.snoozeFilmForWeek(film.id, now);

      expect(
        (await repository.loadAvailableFilms(now)).map((item) => item.id),
        isNot(contains(film.id)),
      );
      expect(
        (await repository.loadAvailableFilms(
          now.add(const Duration(days: 6, hours: 23, minutes: 59)),
        )).map((item) => item.id),
        isNot(contains(film.id)),
      );
      expect(
        (await repository.loadAvailableFilms(now.add(const Duration(days: 7))))
            .map((item) => item.id),
        contains(film.id),
      );
    },
  );

  testWidgets(
    'wheel asks whether to watch, records answer, and allows reroll',
    (tester) async {
      final now = DateTime(2026, 11, 6, 15);
      await tester.pumpWidget(
        localizedTestApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CinemaNightWidget(
                clock: () => now,
                random: () => const _FixedRandom(false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('daily-cinema-pointer')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('daily-cinema-spin')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('daily-cinema-result')), findsOneWidget);
      expect(find.text('Будем смотреть этот фильм?'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('daily-cinema-watched')));
      await tester.pumpAndSettle();
      expect(find.text('Отличный выбор! Приятного вечера.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('daily-cinema-skip-week')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('daily-cinema-spin')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('daily-cinema-result')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('custom film can be added and removed only for today', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 6, 15);
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CinemaNightWidget(
              clock: () => now,
              random: () => const _FixedRandom(false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('daily-cinema-film-input')),
      'Мой фильм',
    );
    await tester.tap(find.byKey(const ValueKey('daily-cinema-add-film')));
    await tester.pumpAndSettle();
    final filmChip = find.byKey(
      const ValueKey('daily-cinema-remove-custom:мой фильм'),
    );
    expect(filmChip, findsOneWidget);

    await tester.ensureVisible(filmChip);
    await tester.pump();
    await tester.tap(find.byTooltip('Убрать Мой фильм из рулетки на сегодня'));
    await tester.pumpAndSettle();
    expect(filmChip, findsNothing);

    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesDailyCinemaRepository(
      preferences: preferences,
    );
    expect(
      (await repository.loadAvailableFilms(now))
          .any((film) => film.id == 'custom:мой фильм'),
      isFalse,
    );
    expect(
      (await repository.loadAvailableFilms(DateTime(2026, 11, 7)))
          .any((film) => film.id == 'custom:мой фильм'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'declining a movie removes it from the visible choices for a week',
    (tester) async {
      final now = DateTime(2026, 11, 6, 15);
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesDailyCinemaRepository(
        preferences: preferences,
      );
      await tester.pumpWidget(
        localizedTestApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CinemaNightWidget(
                clock: () => now,
                repository: repository,
                random: () => const _FixedRandom(false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daily-cinema-spin')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final resultText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('daily-cinema-result')),
          matching: find.byType(Text),
        ),
      );
      final title = resultText.data!.replaceFirst('Сегодня смотрим: ', '');
      expect(find.widgetWithText(InputChip, title), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('daily-cinema-skip-week')));
      await tester.pumpAndSettle();
      expect(find.text('Фильм убран из рулетки на неделю.'), findsOneWidget);
      expect(find.widgetWithText(InputChip, title), findsNothing);
      expect(
        (await repository.loadAvailableFilms(now.add(const Duration(days: 6))))
            .any((film) => film.titleRu == title),
        isFalse,
      );
      expect(
        (await repository.loadAvailableFilms(now.add(const Duration(days: 7))))
            .any((film) => film.titleRu == title),
        isTrue,
      );
    },
  );
}
