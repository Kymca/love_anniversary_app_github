import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/countdown_event.dart';
import 'package:love_anniversary_app/models/daily_mood.dart';
import 'package:love_anniversary_app/services/countdown_repository.dart';
import 'package:love_anniversary_app/services/mood_repository.dart';
import 'package:love_anniversary_app/services/mood_pair_repository.dart';
import 'package:love_anniversary_app/widgets/countdown_widget.dart';
import 'package:love_anniversary_app/widgets/mood_calendar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  final now = DateTime(2026, 11, 6, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'countdown persists edits and keeps its original progress start',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = CountdownRepository(
        preferences: preferences,
        clock: () => now,
      );
      final event = await repository.add(
        title: 'Отпуск',
        eventDate: DateTime(2026, 11, 16, 12),
      );
      expect(event.progressAt(DateTime(2026, 11, 11, 12)), closeTo(0.5, 0.001));

      await repository.update(
        id: event.id,
        title: 'Наш отпуск',
        eventDate: DateTime(2026, 11, 26, 12),
      );
      final restored = await CountdownRepository(
        preferences: preferences,
        clock: () => now,
      ).load();
      expect(restored.single.title, 'Наш отпуск');
      expect(restored.single.createdAt, now);
      expect(
        restored.single.progressAt(DateTime(2026, 11, 16, 12)),
        closeTo(0.5, 0.001),
      );

      await repository.delete(event.id);
      expect(await repository.load(), isEmpty);
    },
  );

  test('past countdown is complete and marked as passed', () {
    final event = CountdownEvent(
      id: 'synthetic-past',
      title: 'Вчерашняя прогулка',
      createdAt: DateTime(2026, 11, 1),
      eventDate: DateTime(2026, 11, 5),
    );

    expect(event.progressAt(now), 1);
    expect(event.hasPassed, isTrue);
  });

  test(
    'mood changes append to a dated history and latest response is persistent',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = MoodRepository(preferences: preferences);
      final first = await repository.recordToday(DailyMood.joyful, now: now);
      final second = await repository.recordToday(
        DailyMood.blue,
        now: DateTime(2026, 11, 6, 23, 58),
      );
      final restored = await MoodRepository(preferences: preferences).load();
      final history = await repository.historyFor(now);

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(restored, hasLength(2));
      expect(history.map((entry) => entry.mood), [
        DailyMood.joyful,
        DailyMood.blue,
      ]);
      expect((await repository.entryFor(now))?.mood, DailyMood.blue);
      expect(restored.first.compliment, first!.compliment);
      expect(restored.last.dateKey, '2026-11-06');
    },
  );

  test('legacy mood entries without timestamps remain readable', () async {
    SharedPreferences.setMockInitialValues({
      MoodRepository.storageKey:
          '[{"date":"2026-11-06","mood":"joyful","compliment":"legacy"}]',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = MoodRepository(preferences: preferences);

    final legacyEntry = (await repository.historyFor(now)).single;
    expect(legacyEntry.mood, DailyMood.joyful);
    expect(legacyEntry.compliment, 'legacy');
    expect(legacyEntry.recordedAt, isNull);

    await repository.record(
      DailyMood.angry,
      date: now,
      recordedAt: DateTime(2026, 11, 6, 18),
    );
    expect((await repository.historyFor(now)).map((entry) => entry.mood), [
      DailyMood.joyful,
      DailyMood.angry,
    ]);
  });

  testWidgets('countdown supports add, edit and delete', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final repository = CountdownRepository(
      preferences: preferences,
      clock: () => now,
    );
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: CountdownWidget(repository: repository, clock: () => now),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Добавить событие'));
    await _settleDialog(tester);
    await tester.enterText(find.byType(TextField), 'Поездка');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Сохранить'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Сохранить'));
    await _pump(tester);
    expect(await repository.load(), hasLength(1));
    expect((await repository.load()).single.title, 'Поездка');
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Добавьте поездку, день рождения или другую важную дату.'),
      findsNothing,
    );
    expect(find.text('Не удалось загрузить события.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Поездка', skipOffstage: false), findsOneWidget);
    expect(find.text('Осталось 1 дн.'), findsOneWidget);

    await tester.tap(find.byTooltip('Изменить событие Поездка'));
    await _settleDialog(tester);
    await tester.enterText(find.byType(TextField), 'Море');
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await _pump(tester);
    expect(find.text('Море'), findsOneWidget);

    await tester.tap(find.byTooltip('Удалить событие Море'));
    await _pump(tester);
    expect(find.text('Море'), findsNothing);
  });

  testWidgets('mood selection shows one daily compliment and calendar marker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesMoodPairRepository(
      preferences: preferences,
    );
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: MoodCalendarWidget(repository: repository, clock: () => now),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Радостно'));
    await _pump(tester);

    final entryHistory = await repository.historyFor('first', now);
    final entry = entryHistory.last;
    expect(entry, isNotNull);
    expect(find.text('Сегодня: Радостно'), findsOneWidget);
    expect(
      find.text(
        'Сохрани этот яркий момент — пусть утка тоже порадуется вместе с тобой.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('change-today-mood')), findsOneWidget);
    expect(find.textContaining('сейчас'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('change-today-mood')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mood-dialog-choice-blue')));
    await _pump(tester);

    final history = await repository.historyFor('first', now);
    expect(history.map((entry) => entry.mood), [
      DailyMood.joyful,
      DailyMood.blue,
    ]);
    expect(find.text('Сегодня: Грустно'), findsOneWidget);
    expect(find.textContaining('Радостно'), findsOneWidget);
    expect(find.textContaining('сейчас'), findsOneWidget);
  });

  testWidgets('tapping a calendar date opens its history and permits changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesMoodPairRepository(
      preferences: preferences,
    );
    final selectedDate = DateTime(2026, 11, 5);
    await repository.record('first', DailyMood.angry, date: selectedDate);
    await repository.record('first', DailyMood.calm, date: selectedDate);

    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: MoodCalendarWidget(repository: repository, clock: () => now),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Злюсь'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('mood-calendar-date-2026-11-05')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Настроение за'), findsOneWidget);
    expect(find.textContaining('Злюсь'), findsOneWidget);
    expect(find.textContaining('Спокойно'), findsOneWidget);
    expect(find.textContaining('сейчас'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('change-selected-date-mood')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mood-dialog-choice-joyful')));
    await _pump(tester);

    final history = await repository.historyFor('first', selectedDate);
    expect(history.map((entry) => entry.mood), [
      DailyMood.angry,
      DailyMood.calm,
      DailyMood.joyful,
    ]);
  });
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _settleDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}
