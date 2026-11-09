import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/screens/mini_games/grocery_store_screen.dart';
import 'package:love_anniversary_app/screens/mini_games/warehouse_game_engine.dart';
import 'package:love_anniversary_app/screens/mini_games/warehouse_work_screen.dart';
import 'package:love_anniversary_app/services/grocery_wallet.dart';
import 'package:love_anniversary_app/services/warehouse_work_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  group('warehouse rewards', () {
    test('awards 500 for 15, 250 for 8, and nothing for 7', () {
      expect(warehouseRewardFor(15), 500);
      expect(warehouseRewardFor(8), 250);
      expect(warehouseRewardFor(7), 0);
    });

    test('persists progress, enforces cooldown, and grants once', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var now = DateTime(2026, 11, 9, 10);
      final repository = WarehouseWorkRepository(
        preferences: preferences,
        clock: () => now,
      );
      final wallet = await GroceryWallet.open(preferences: preferences);
      final initialBalance = wallet.balance;

      final started = await repository.beginWork();
      await repository.saveProgress(started.activeRunId!, caught: 4, missed: 2);
      final restartedRepository = WarehouseWorkRepository(
        preferences: preferences,
        clock: () => now,
      );
      final resumed = await restartedRepository.beginWork();
      expect(resumed.activeRunId, started.activeRunId);
      expect(resumed.caught, 4);
      expect(resumed.missed, 2);

      now = now.add(const Duration(hours: 1));
      await restartedRepository.completeWork(
        started.activeRunId!,
        caught: 8,
        missed: 7,
        wallet: wallet,
      );
      expect(wallet.balance, initialBalance + 250);
      final reloadedWallet = await GroceryWallet.open(preferences: preferences);
      await restartedRepository.completeWork(
        started.activeRunId!,
        caught: 8,
        missed: 7,
        wallet: reloadedWallet,
      );
      expect(reloadedWallet.balance, initialBalance + 250);

      now = now.add(const Duration(hours: 2, minutes: 59, seconds: 59));
      await expectLater(
        restartedRepository.beginWork(),
        throwsA(isA<WarehouseCooldownException>()),
      );
      now = now.add(const Duration(seconds: 1));
      expect(
        (await restartedRepository.beginWork()).activeRunId,
        isNot(started.activeRunId),
      );
    });

    test('completes a full 15/15 run and grants the perfect reward', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = WarehouseWorkRepository(
        preferences: preferences,
        clock: () => DateTime(2026, 11, 9, 10),
      );
      final wallet = await GroceryWallet.open(preferences: preferences);
      final engine = WarehouseGameEngine(
        caught: 0,
        missed: 0,
        seed: 1,
        dropSpeed: 3,
        spawnInterval: 0.05,
        catchY: 0.2,
        catchHalfWidth: 1,
      );
      for (var frame = 0; frame < 300 && !engine.isComplete; frame++) {
        engine.advance(1 / 60);
      }
      expect((engine.caught, engine.missed), (15, 0));

      final run = await repository.beginWork();
      final completed = await repository.completeWork(
        run.activeRunId!,
        caught: engine.caught,
        missed: engine.missed,
        wallet: wallet,
      );

      expect(completed.activeRunId, isNull);
      expect(completed.completedRunId, run.activeRunId);
      expect((completed.completedCaught, completed.completedMissed), (15, 0));
      expect(completed.rewardGranted, isTrue);
      expect(wallet.balance, 500);
    });

    test(
      'serializes overlapping progress saves and completion recovery',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final repository = WarehouseWorkRepository(
          preferences: preferences,
          clock: () => DateTime(2026, 11, 9, 10),
        );
        final wallet = await GroceryWallet.open(preferences: preferences);
        final run = await repository.beginWork();
        final runId = run.activeRunId!;

        final save = repository.saveProgress(runId, caught: 14, missed: 0);
        final complete = repository.completeWork(
          runId,
          caught: 15,
          missed: 0,
          wallet: wallet,
        );
        final duplicateComplete = repository.completeWork(
          runId,
          caught: 15,
          missed: 0,
          wallet: wallet,
        );
        await Future.wait([save, complete, duplicateComplete]);

        final completed = await repository.load();
        expect(completed.activeRunId, isNull);
        expect(completed.completedRunId, runId);
        expect((completed.completedCaught, completed.completedMissed), (15, 0));
        expect(wallet.balance, 500);

        final restartedRepository = WarehouseWorkRepository(
          preferences: preferences,
          clock: () => DateTime(2026, 11, 9, 10),
        );
        final restartedWallet = await GroceryWallet.open(
          preferences: preferences,
        );
        await restartedRepository.recoverPendingReward(
          completed,
          restartedWallet,
        );
        expect(restartedWallet.balance, 500);
        expect((await restartedRepository.load()).rewardGranted, isTrue);
      },
    );
  });

  test('game engine settles exactly 15 boxes with fair catch boundaries', () {
    final engine = WarehouseGameEngine(
      caught: 0,
      missed: 0,
      seed: 1,
      dropSpeed: 3,
      spawnInterval: 0.05,
      catchY: 0.2,
      catchHalfWidth: 1,
    );
    for (var frame = 0; frame < 300 && !engine.isComplete; frame++) {
      engine.advance(1 / 60);
    }

    expect(engine.isComplete, isTrue);
    expect(engine.boxesSettled, 15);
    expect(engine.caught, 15);
    expect(engine.missed, 0);
  });

  testWidgets('grocery store switches between shopping and warehouse work', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final wallet = await GroceryWallet.open(preferences: preferences);
    await tester.pumpWidget(
      localizedTestApp(
        home: GroceryStoreScreen(
          duckName: 'Кряква',
          wallet: wallet,
          catalogSeed: 1,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('grocery-store-work-switch')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('warehouse-start-work')), findsNothing);
    await tester.tap(find.text('Работа'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('warehouse-start-work')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('grocery-store-work-switch')),
      findsOneWidget,
    );
    await tester.tap(find.text('Магазин'));
    await tester.pump();
    expect(find.byKey(const ValueKey('warehouse-start-work')), findsNothing);
    expect(find.textContaining('Выбери продукты'), findsOneWidget);
  });

  testWidgets('return from embedded work result switches to grocery store', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime(2026, 11, 9, 10);
    await preferences.setString(
      WarehouseWorkRepository.storageKey,
      jsonEncode(
        WarehouseWorkState(
          lastStartedAt: now.subtract(const Duration(minutes: 1)),
          lastCompletedAt: now,
          completedRunId: 'completed-run',
          completedCaught: 15,
          completedMissed: 0,
          completedReward: 500,
          rewardGranted: true,
        ).toJson(),
      ),
    );
    final wallet = await GroceryWallet.open(preferences: preferences);
    await tester.pumpWidget(
      localizedTestApp(
        home: GroceryStoreScreen(
          duckName: 'Кряква',
          wallet: wallet,
          catalogSeed: 1,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Работа'));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('warehouse-result-title')),
      findsOneWidget,
    );
    expect(find.text('Отличная смена!'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('warehouse-return-home')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('grocery-store-work-switch')),
      findsOneWidget,
    );
    expect(find.text('Выбери продукты на полках'), findsOneWidget);
    expect(find.byKey(const ValueKey('warehouse-result-title')), findsNothing);
  });

  testWidgets('warehouse screen has responsive controls and Russian copy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime(2026, 11, 9, 10);
    final wallet = await GroceryWallet.open(preferences: preferences);
    await tester.pumpWidget(
      localizedTestApp(
        home: WarehouseWorkScreen(
          repository: WarehouseWorkRepository(
            preferences: preferences,
            clock: () => now,
          ),
          wallet: wallet,
          clock: () => now,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final start = find.byKey(const ValueKey('warehouse-start-work'));
    expect(start, findsOneWidget);
    await tester.tap(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.byKey(const ValueKey('warehouse-game-scene')), findsOneWidget);
    expect(find.byKey(const ValueKey('warehouse-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('warehouse-move-left')), findsOneWidget);
    expect(find.byKey(const ValueKey('warehouse-move-right')), findsOneWidget);
    final stage = find.byKey(const ValueKey('warehouse-stage-aspect'));
    expect(tester.widget<AspectRatio>(stage).aspectRatio, 4 / 3);
    final stageSize = tester.getSize(stage);
    expect(stageSize.width / stageSize.height, closeTo(4 / 3, 0.01));
    final background = tester.widget<Image>(
      find.byKey(const ValueKey('warehouse-background-image')),
    );
    expect(background.fit, BoxFit.fill);
    expect(background.filterQuality, FilterQuality.none);
    expect(background.image, isA<AssetImage>());
    expect(
      (background.image as AssetImage).assetName,
      'assets/images/warehouse/warehouse_background.png',
    );
    expect(find.byKey(const ValueKey('warehouse-box-0')), findsOneWidget);
    final player = find.byKey(const ValueKey('warehouse-player'));
    final before = tester.widget<Positioned>(player).left!;
    await tester.tap(find.byKey(const ValueKey('warehouse-move-right')));
    await tester.pump();
    expect(tester.widget<Positioned>(player).left!, greaterThan(before));
    expect(find.text('Завершено: 0 из 15'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('warehouse cooldown message is localized in Ukrainian', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime(2026, 11, 9, 10);
    await preferences.setString(
      WarehouseWorkRepository.storageKey,
      jsonEncode(WarehouseWorkState(lastStartedAt: now).toJson()),
    );
    final wallet = await GroceryWallet.open(preferences: preferences);
    await tester.pumpWidget(
      localizedTestApp(
        locale: const Locale('uk'),
        home: WarehouseWorkScreen(
          repository: WarehouseWorkRepository(
            preferences: preferences,
            clock: () => now,
          ),
          wallet: wallet,
          clock: () => now,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Качечка втомилася'), findsOneWidget);
    expect(find.textContaining('3 год 0 хв'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('warehouse-start-work')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('warehouse completion screens match each payout threshold', (
    tester,
  ) async {
    const outcomes = [
      (caught: 15, title: 'Отличная смена!', reward: 'Заработано: 500 ₴'),
      (caught: 8, title: 'Хорошая работа!', reward: 'Заработано: 250 ₴'),
      (caught: 7, title: 'Смена завершена', reward: 'Заработано: 0 ₴'),
    ];
    final now = DateTime(2026, 11, 9, 10);
    for (final outcome in outcomes) {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final state = WarehouseWorkState(
        lastStartedAt: now.subtract(const Duration(minutes: 1)),
        lastCompletedAt: now,
        completedRunId: 'run-${outcome.caught}',
        completedCaught: outcome.caught,
        completedMissed: 15 - outcome.caught,
        completedReward: warehouseRewardFor(outcome.caught),
        rewardGranted: true,
      );
      await preferences.setString(
        WarehouseWorkRepository.storageKey,
        jsonEncode(state.toJson()),
      );
      final wallet = await GroceryWallet.open(preferences: preferences);
      await tester.pumpWidget(
        localizedTestApp(
          home: WarehouseWorkScreen(
            repository: WarehouseWorkRepository(
              preferences: preferences,
              clock: () => now,
            ),
            wallet: wallet,
            clock: () => now,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(outcome.title), findsOneWidget);
      expect(find.text(outcome.reward), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
