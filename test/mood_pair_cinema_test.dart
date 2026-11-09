import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/daily_mood.dart';
import 'package:love_anniversary_app/services/mood_pair_repository.dart';

import 'dart:convert';

import 'package:love_anniversary_app/widgets/mood_pair_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  final today = DateTime(2026, 11, 6, 15);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'pair mood persists both local entries and selects duck reactions',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesMoodPairRepository(
        preferences: preferences,
      );

      await repository.record('first', DailyMood.blue, date: today);
      expect((await repository.loadFor(today)).moods, hasLength(1));
      final bothBlue = await repository.record(
        'second',
        DailyMood.blue,
        date: today,
      );
      expect(bothBlue.reaction, contains('пледом и приносит чай'));

      final nextDay = DateTime(2026, 11, 7);
      await repository.record('first', DailyMood.joyful, date: nextDay);
      final bothJoyful = await repository.record(
        'second',
        DailyMood.joyful,
        date: nextDay,
      );
      expect(bothJoyful.reaction, contains('танец'));
    },
  );

  testWidgets('pair mood widget retains local-only sync notice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: MoodPairWidget(
            repository: SharedPreferencesMoodPairRepository(
              preferences: preferences,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Для синхронизации нужен backend.'),
      findsOneWidget,
    );
  });

  test('legacy mood names migrate to stable participant sides', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesMoodPairRepository.storageKey: jsonEncode({
        '2026-11-06': {'Алина': 'angry', 'Партнёр': 'joyful'},
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    final moods = await SharedPreferencesMoodPairRepository(
      preferences: preferences,
    ).loadFor(today);

    expect(moods.moods, {'first': DailyMood.angry, 'second': DailyMood.joyful});
    final saved = jsonDecode(
      preferences.getString(SharedPreferencesMoodPairRepository.storageKey)!,
    ) as Map<String, dynamic>;
    expect(saved['2026-11-06'], {'first': 'angry', 'second': 'joyful'});
  });

  testWidgets('choosing partner mood calls back and persists locally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesMoodPairRepository(
      preferences: preferences,
    );
    var changed = false;
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: MoodPairWidget(
            repository: repository,
            participantNames: const {'first': 'Маша', 'second': 'Илья'},
            onChanged: () => changed = true,
            clock: () => today,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Маша'), findsOneWidget);
    expect(find.text('Илья'), findsOneWidget);
    final angerChoice = find.byKey(const ValueKey('mood-choice-first-angry'));
    expect(tester.widget<IconButton>(angerChoice).onPressed, isNotNull);
    await tester.tap(angerChoice);
    await tester.pumpAndSettle();
    expect(changed, isTrue);
    expect((await repository.loadFor(today)).moods['first'], DailyMood.angry);
    final angerDecoration =
        (tester.widget<IconButton>(angerChoice).icon as Container).decoration
            as BoxDecoration;
    expect(angerDecoration.border, isA<Border>());
    expect((angerDecoration.border! as Border).top.color, Colors.black);
    expect((angerDecoration.border! as Border).top.width, 1);

    final joyfulChoice = find.byKey(const ValueKey('mood-choice-first-joyful'));
    await tester.tap(joyfulChoice);
    await tester.pumpAndSettle();
    expect((await repository.loadFor(today)).moods['first'], DailyMood.joyful);
    final joyfulDecoration =
        (tester.widget<IconButton>(joyfulChoice).icon as Container).decoration
            as BoxDecoration;
    expect(joyfulDecoration.border, isA<Border>());
    expect((joyfulDecoration.border! as Border).top.color, Colors.black);
    expect((joyfulDecoration.border! as Border).top.width, 1);

    await tester.tap(find.byKey(const ValueKey('mood-choice-second-blue')));
    await tester.pumpAndSettle();
    expect((await repository.loadFor(today)).moods['second'], DailyMood.blue);
  });
}
