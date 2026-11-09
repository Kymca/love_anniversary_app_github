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
    },
  );

  testWidgets('roulette switches categories, adds a choice, and spins', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      localizedTestApp(home: RouletteScreen(random: () => math.Random(2))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Рулетка свиданий'), findsOneWidget);
    expect(find.byKey(const ValueKey('roulette-wheel')), findsOneWidget);

    await tester.tap(find.text('Кино'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('roulette-choice-input')),
      'Наш фильм',
    );
    await tester.tap(find.byKey(const ValueKey('roulette-add-choice')));
    await tester.pumpAndSettle();
    expect(find.text('Наш фильм'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('roulette-spin')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('roulette-result')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
