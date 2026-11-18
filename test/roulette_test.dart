import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/screens/roulette_screen.dart';
import 'package:love_anniversary_app/services/roulette_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'custom roulette choices persist per category and ignore duplicates',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesRouletteRepository(
        preferences: preferences,
      );
      await repository.addChoice(RouletteCategory.food, '  Паста  ');
      await repository.addChoice(RouletteCategory.food, 'паста');
      await repository.addChoice(RouletteCategory.movie, 'Комедия');

      expect(await repository.loadCustomChoices(RouletteCategory.food), [
        'Паста',
      ]);
      expect(await repository.loadCustomChoices(RouletteCategory.movie), [
        'Комедия',
      ]);

      await repository.removeChoice(RouletteCategory.food, 'Паста');
      expect(
        await repository.loadCustomChoices(RouletteCategory.food),
        isEmpty,
      );
      expect(await repository.loadSharedChoices(RouletteCategory.food), [
        'Паста',
      ]);
      await repository.addChoice(RouletteCategory.food, 'паста');
      expect(await repository.loadCustomChoices(RouletteCategory.food), [
        'Паста',
      ]);
    },
  );

  test(
    'movies become watched next day and food/activity return after 48 hours',
    () async {
      final preferences = await SharedPreferences.getInstance();
      var now = DateTime.utc(2026, 11, 10, 9);
      final repository = SharedPreferencesRouletteRepository(
        preferences: preferences,
        clock: () => now,
      );
      await repository.addChoice(RouletteCategory.food, 'Soup');
      await repository.applyChoice(
        RouletteCategory.food,
        'Soup',
        SharedPreferencesRouletteRepository.customChoiceKey('Soup'),
      );
      await repository.addChoice(RouletteCategory.activity, 'Walk');
      await repository.applyChoice(
        RouletteCategory.activity,
        'Walk',
        SharedPreferencesRouletteRepository.customChoiceKey('Walk'),
      );
      await repository.addChoice(RouletteCategory.movie, 'Film');
      await repository.applyChoice(
        RouletteCategory.movie,
        'Film',
        SharedPreferencesRouletteRepository.customChoiceKey('Film'),
      );

      expect(
        await repository.loadCustomChoices(RouletteCategory.food),
        isEmpty,
      );
      expect(
        await repository.loadCustomChoices(RouletteCategory.activity),
        isEmpty,
      );
      expect(await repository.loadCustomChoices(RouletteCategory.movie), [
        'Film',
      ]);
      expect(await repository.loadSharedChoices(RouletteCategory.food), [
        'Soup',
      ]);

      now = now.add(const Duration(hours: 15));
      expect(
        await repository.loadCustomChoices(RouletteCategory.movie),
        isEmpty,
      );
      expect(
        await repository.loadExcludedChoiceKeys(RouletteCategory.movie),
        contains(SharedPreferencesRouletteRepository.customChoiceKey('Film')),
      );

      now = now.add(const Duration(hours: 33));
      expect(await repository.loadCustomChoices(RouletteCategory.food), [
        'Soup',
      ]);
      expect(await repository.loadCustomChoices(RouletteCategory.activity), [
        'Walk',
      ]);
      now = now.add(const Duration(days: 30));
      expect(
        await repository.loadCustomChoices(RouletteCategory.movie),
        isEmpty,
      );
    },
  );

  test('two pair members see shared roulette edits and removals', () async {
    final backend = _SharedRouletteBackend();
    final firstMember = _SharedRouletteRepository(backend);
    final secondMember = _SharedRouletteRepository(backend);

    final changed = secondMember.watchChanges(RouletteCategory.food).first;
    await firstMember.addChoice(RouletteCategory.food, 'Паста');
    await expectLater(changed, completes);
    expect(await secondMember.loadCustomChoices(RouletteCategory.food), [
      'Паста',
    ]);

    await firstMember.removeChoice(RouletteCategory.food, 'Паста');
    expect(
      await secondMember.loadCustomChoices(RouletteCategory.food),
      isEmpty,
    );
    expect(await secondMember.loadSharedChoices(RouletteCategory.food), [
      'Паста',
    ]);
  });

  testWidgets('roulette switches categories, adds a choice, and spins', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesRouletteRepository(
      preferences: preferences,
    );
    await tester.pumpWidget(
      localizedTestApp(
        home: RouletteScreen(
          repository: repository,
          random: () => math.Random(2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Рулетка свиданий'), findsOneWidget);
    expect(find.byKey(const ValueKey('roulette-wheel')), findsOneWidget);

    await tester.tap(find.text('Кино'));
    await tester.pumpAndSettle();
    expect(find.text('Рататуй'), findsOneWidget);
    expect(find.text('Приключения Паддингтона'), findsOneWidget);
    expect(find.text('Романтическая комедия'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('roulette-choice-input')),
      'Наш фильм',
    );
    await tester.tap(find.byKey(const ValueKey('roulette-add-choice')));
    await tester.pumpAndSettle();
    expect(await repository.loadCustomChoices(RouletteCategory.movie), [
      'Наш фильм',
    ]);

    await tester.tap(find.byKey(const ValueKey('roulette-spin')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('roulette-result')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('roulette-do-this')));
    await tester.pumpAndSettle();
    expect(find.text('Выбор сохранён'), findsOneWidget);
    expect(
      await repository.loadExcludedChoiceKeys(RouletteCategory.movie),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared spin gives both pair members the same result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _SharedRouletteBackend();
    addTearDown(() async {
      await backend.changes.close();
      await backend.spinChanges.close();
    });
    final firstMember = _SharedRouletteRepository(backend);
    final secondMember = _SharedRouletteRepository(backend);
    await tester.pumpWidget(
      localizedTestApp(
        home: Row(
          children: [
            Expanded(child: RouletteScreen(repository: firstMember)),
            Expanded(child: RouletteScreen(repository: secondMember)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Кино').last);
    await tester.pumpAndSettle();
    expect(find.text('Рататуй'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('roulette-spin')).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    final results = tester
        .widgetList<Text>(find.byKey(const ValueKey('roulette-result')))
        .map((text) => text.data)
        .toList();
    expect(results, hasLength(2));
    expect(results[0], results[1]);
    final rouletteWidgets = tester
        .widgetList<SegmentedButton<RouletteCategory>>(
          find.byType(SegmentedButton<RouletteCategory>),
        );
    expect(rouletteWidgets, hasLength(2));
    expect(rouletteWidgets.last.selected, {RouletteCategory.food});
    expect(tester.takeException(), isNull);
  });
}

class _SharedRouletteBackend {
  final Map<RouletteCategory, Map<String, bool>> choices = {};
  final StreamController<RouletteCategory> changes =
      StreamController<RouletteCategory>.broadcast(sync: true);
  final StreamController<RouletteSpin> spinChanges =
      StreamController<RouletteSpin>.broadcast(sync: true);
  var nextSpinId = 0;
}

class _SharedRouletteRepository implements RouletteRepository {
  _SharedRouletteRepository(this.backend);

  final _SharedRouletteBackend backend;

  @override
  Future<void> addChoice(RouletteCategory category, String choice) async {
    final normalized = choice.trim();
    if (normalized.isEmpty || normalized.length > 80) {
      throw ArgumentError.value(choice, 'choice');
    }
    backend.choices.putIfAbsent(category, () => {})[normalized] = true;
    backend.changes.add(category);
  }

  @override
  Future<void> applyChoice(
    RouletteCategory category,
    String choice,
    String choiceKey,
  ) async {}

  @override
  Future<List<String>> loadCustomChoices(RouletteCategory category) async =>
      List.unmodifiable(
        (backend.choices[category] ?? const {}).entries
            .where((entry) => entry.value)
            .map((entry) => entry.key),
      );

  @override
  Future<List<String>> loadExcludedChoiceKeys(
    RouletteCategory category,
  ) async => const [];

  @override
  Future<List<String>> loadSharedChoices(RouletteCategory category) async =>
      List.unmodifiable((backend.choices[category] ?? const {}).keys);

  @override
  Future<void> removeChoice(RouletteCategory category, String choice) async {
    final choices = backend.choices[category] ?? {};
    for (final entry in choices.keys.toList()) {
      if (entry.toLowerCase() == choice.trim().toLowerCase()) {
        choices[entry] = false;
      }
    }
    backend.changes.add(category);
  }

  @override
  Stream<void> watchChanges(RouletteCategory category) => backend.changes.stream
      .where((changed) => changed == category)
      .map((_) {});

  @override
  Future<RouletteSpin?> startSpin(
    RouletteCategory category,
    String choice,
    String choiceKey,
  ) async {
    final spin = RouletteSpin(
      id: 'spin-${backend.nextSpinId++}',
      category: category,
      choiceKey: choiceKey,
      choice: choice,
      startedAt: DateTime.now().toUtc(),
    );
    backend.spinChanges.add(spin);
    return spin;
  }

  @override
  Stream<RouletteSpin> watchSpins() => backend.spinChanges.stream;
}
