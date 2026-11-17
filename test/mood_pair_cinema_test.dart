import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/daily_mood.dart';
import 'package:love_anniversary_app/services/mood_pair_repository.dart';
import 'package:love_anniversary_app/services/participant_profile_repository.dart';
import 'package:love_anniversary_app/widgets/duck_mood.dart';

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
      final firstMarked = await repository.loadFor(today);
      expect(firstMarked.moods, hasLength(1));
      expect(
        duckPartnerMoodForSide(firstMarked.moods, DuckPartnerSide.second),
        DailyMood.blue,
      );
      final profiles = ParticipantProfileRepository(preferences: preferences);
      await profiles.saveCurrentSide('second');
      final bothBlue = await repository.record(
        'second',
        DailyMood.blue,
        date: today,
      );
      expect(
        duckPartnerMoodForSide(bothBlue.moods, DuckPartnerSide.first),
        DailyMood.blue,
      );
      expect(bothBlue.reaction, contains('пледом и приносит чай'));
      expect(
        (await repository.historyFor('first', today)).single.mood,
        DailyMood.blue,
      );
      expect(
        (await repository.historyFor('second', today)).single.mood,
        DailyMood.blue,
      );

      final nextDay = DateTime(2026, 11, 7);
      await profiles.saveCurrentSide('first');
      await repository.record('first', DailyMood.joyful, date: nextDay);
      await profiles.saveCurrentSide('second');
      final bothJoyful = await repository.record(
        'second',
        DailyMood.joyful,
        date: nextDay,
      );
      expect(bothJoyful.reaction, contains('танец'));
    },
  );

  test('repository rejects mood writes for the other participant', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesMoodPairRepository(
      preferences: preferences,
    );
    await expectLater(
      repository.record('second', DailyMood.angry, date: today),
      throwsA(isA<StateError>()),
    );
    expect((await repository.loadFor(today)).moods, isEmpty);
  });

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
    final profiles = ParticipantProfileRepository(preferences: preferences);
    final repository = SharedPreferencesMoodPairRepository(
      preferences: preferences,
      profileRepository: profiles,
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
    expect(await repository.historyFor('first', today), hasLength(2));
    final joyfulDecoration =
        (tester.widget<IconButton>(joyfulChoice).icon as Container).decoration
            as BoxDecoration;
    expect(joyfulDecoration.border, isA<Border>());
    expect((joyfulDecoration.border! as Border).top.color, Colors.black);
    expect((joyfulDecoration.border! as Border).top.width, 1);

    final partnerChoice = find.byKey(const ValueKey('mood-choice-second-blue'));
    expect(tester.widget<IconButton>(partnerChoice).onPressed, isNull);
    expect((await repository.loadFor(today)).moods['second'], isNull);

    await profiles.saveCurrentSide('second');
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: MoodPairWidget(
            repository: repository,
            participantSide: 'second',
            participantNames: const {'first': 'Маша', 'second': 'Илья'},
            clock: () => today,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final secondChoice = find.byKey(const ValueKey('mood-choice-second-blue'));
    expect(tester.widget<IconButton>(secondChoice).onPressed, isNotNull);
    final firstChoice = find.byKey(const ValueKey('mood-choice-first-angry'));
    expect(tester.widget<IconButton>(firstChoice).onPressed, isNull);
    await tester.tap(secondChoice);
    await tester.pumpAndSettle();
    expect((await repository.loadFor(today)).moods['second'], DailyMood.blue);
  });
}
