import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/countdown_event.dart';
import 'package:love_anniversary_app/models/daily_mood.dart';
import 'package:love_anniversary_app/services/countdown_repository.dart';
import 'package:love_anniversary_app/services/mood_repository.dart';
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
    'mood is recorded once per local date and response is persistent',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = MoodRepository(preferences: preferences);
      final first = await repository.recordToday(DailyMood.joyful, now: now);
      final duplicate = await repository.recordToday(
        DailyMood.blue,
        now: DateTime(2026, 11, 6, 23, 58),
      );
      final restored = await MoodRepository(preferences: preferences).load();

      expect(first, isNotNull);
      expect(duplicate, isNull);
      expect(restored, hasLength(1));
      expect(restored.single.mood, DailyMood.joyful);
      expect(restored.single.compliment, first!.compliment);
      expect(restored.single.dateKey, '2026-11-06');
    },
  );

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
    final repository = MoodRepository(preferences: preferences);
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

    final entry = await repository.entryFor(now);
    expect(entry, isNotNull);
    expect(find.text('Сегодня: Радостно'), findsOneWidget);
    expect(
      find.text(
        'Сохрани этот яркий момент — пусть утка тоже порадуется вместе с тобой.',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Радостно'), findsOneWidget);
    expect(find.byTooltip('Спокойно'), findsNothing);
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
