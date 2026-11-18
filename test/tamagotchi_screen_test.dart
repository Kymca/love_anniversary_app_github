import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/screens/duck_clothing_shop_screen.dart';
import 'package:love_anniversary_app/screens/mini_games/grocery_store_screen.dart';
import 'package:love_anniversary_app/screens/mini_games/warehouse_work_screen.dart';
import 'package:love_anniversary_app/screens/tamagotchi_screen.dart';
import 'package:love_anniversary_app/services/grocery_wallet.dart';
import 'package:love_anniversary_app/widgets/duck_painter.dart';
import 'package:love_anniversary_app/services/pair_repository.dart';
import 'package:love_anniversary_app/services/mood_pair_repository.dart';
import 'package:love_anniversary_app/services/duck_ownership_repository.dart';
import 'package:love_anniversary_app/services/participant_profile_repository.dart';
import 'package:love_anniversary_app/models/daily_mood.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:love_anniversary_app/widgets/duck_sprite.dart';
import 'package:love_anniversary_app/widgets/duck_mood.dart';

import 'test_app.dart';

class _DuckTickerProbe extends StatefulWidget {
  const _DuckTickerProbe({required this.onFrame});

  final ValueChanged<int> onFrame;

  @override
  State<_DuckTickerProbe> createState() => _DuckTickerProbeState();
}

class _DuckTickerProbeState extends State<_DuckTickerProbe>
    with SingleTickerProviderStateMixin {
  late final DuckFrameTicker _clock = DuckFrameTicker(
    vsync: this,
    onFrame: widget.onFrame,
  );

  @override
  void initState() {
    super.initState();
    _clock.start();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> _createLocalPair() async {
  final preferences = await SharedPreferences.getInstance();
  final profiles = ParticipantProfileRepository(preferences: preferences);
  await profiles.saveName('first', 'Тестовый участник');
  await profiles.saveName('second', 'Второй участник');
  await SharedPreferencesPairRepository(preferences: preferences)
      .createPair('Алина');
}

void main() {
  test('duck recall control is unavailable outside debug mode', () {
    expect(shouldShowDuckRecall(debugMode: false), isFalse);
    expect(shouldShowDuckRecall(debugMode: true), isTrue);
  });

  testWidgets('pixel duck animates its wings and heart burst when tapped', (
    tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DuckPetWidget(
            size: const Size(240, 205),
            onTap: () => tapCount++,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('pixel-duck-sprite')), findsOneWidget);
    final initialAnimation = tester
        .widget<CustomPaint>(find.byKey(const ValueKey('pixel-duck-animation')))
        .painter;
    await tester.tap(find.byType(DuckPetWidget));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tapCount, 1);
    final jump = tester.widget<Transform>(
      find.byKey(const ValueKey('duck-jump-transform')),
    );
    expect(jump.transform.getTranslation().y, lessThan(-5));
    expect(find.byKey(const ValueKey('pixel-duck-hearts')), findsOneWidget);
    expect(
      identical(
        initialAnimation,
        tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('pixel-duck-animation')),
            )
            .painter,
      ),
      isFalse,
      reason: 'Wing effects should update throughout the idle animation.',
    );
    await tester.pump(const Duration(milliseconds: 520));
    final landed = tester.widget<Transform>(
      find.byKey(const ValueKey('duck-jump-transform')),
    );
    expect(landed.transform.getTranslation().y, closeTo(0, 3));
    expect(tester.takeException(), isNull);
  });

  test('partner moods map to cute duck emotions and correct opposite role', () {
    final moods = {'Алина': DailyMood.angry, 'Партнёр': DailyMood.joyful};
    expect(
      duckPartnerMoodForSide(moods, DuckPartnerSide.first),
      DailyMood.joyful,
    );
    expect(
      duckPartnerMoodForSide(moods, DuckPartnerSide.second),
      DailyMood.angry,
    );
    expect(
      duckEmotionForMood(duckPartnerMoodForSide(moods, DuckPartnerSide.second)),
      DuckEmotion.angry,
    );
    expect(duckEmotionForMood(null), DuckEmotion.neutral);
  });

  test('partner handoff directions are opposite for each role', () {
    expect(
      duckTransitionHorizontalDirection(DuckPartnerSide.first),
      1,
      reason: 'The first partner exits right and enters from the right.',
    );
    expect(
      duckTransitionHorizontalDirection(DuckPartnerSide.second),
      -1,
      reason: 'The second partner exits left and enters from the left.',
    );
  });

  test('duck animation timelines sample elapsed time at 30 fps', () {
    expect(duckAnimationFramesPerSecond, 30);
    expect(duckAnimationFrameInterval.inMicroseconds, 33333);
    expect(
      duckAnimationFrameIndex(
        duckAnimationFrameInterval + const Duration(microseconds: 1),
      ),
      1,
    );
    expect(duckAnimationFrameIndex(const Duration(microseconds: 999999)), 29);
    expect(duckAnimationFrameIndex(const Duration(seconds: 1)), 30);
    expect(duckAnimationFrameCount(duckIdleAnimationDuration), 54);
    expect(duckAnimationFrameCount(duckJumpAnimationDuration), 16);
    expect(duckAnimationFrameCount(duckPartnerTransitionDuration), 14);
    expect(duckAnimationFrameCount(duckJoyHalfDuration), 26);
    expect(duckAnimationFrameCount(duckStoreJoyDuration), 20);
    expect(duckAnimationFrameCount(duckStoreWalkDuration), 23);
    expect(duckAnimationFrameCount(duckStoreGaitDuration), 38);
    expect(duckAnimationProgressAtFrame(16, duckJumpAnimationDuration), 1);
    expect(duckAnimationProgressAtFrame(14, duckPartnerTransitionDuration), 1);
    for (var pose = 0; pose < duckFrontFrameCount; pose++) {
      expect(
        duckSpriteFrameForProgress(
          duckAnimationProgressAtFrame(
            pose * 9,
            duckIdleAnimationDuration,
            loop: true,
          ),
        ),
        pose,
      );
    }
    expect(
      duckAnimationProgressAtFrame(54, duckIdleAnimationDuration, loop: true),
      0,
    );
    expect(
      duckAnimationProgressAtFrame(30, const Duration(seconds: 1), loop: true),
      0,
    );
    expect(duckJoyProgressAtFrame(0), 0);
    expect(duckJoyProgressAtFrame(52), 0);
  });

  testWidgets('duck ticker emits sampled steps, not every vsync', (
    tester,
  ) async {
    final emittedFrames = <int>[];
    await tester.pumpWidget(_DuckTickerProbe(onFrame: emittedFrames.add));

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(emittedFrames, isEmpty);

    await tester.pump(const Duration(milliseconds: 2));
    expect(emittedFrames, [1]);

    await tester.pump(const Duration(milliseconds: 32));
    expect(emittedFrames, [1]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(emittedFrames, [1, 2]);
  });

  testWidgets('role transition advances in sampled 30fps steps', (
    tester,
  ) async {
    Widget transition(DuckPartnerSide side) => MaterialApp(
      home: Center(
        child: DuckPartnerTransition(
          side: side,
          child: SizedBox(key: ValueKey(side), width: 240, height: 205),
        ),
      ),
    );

    await tester.pumpWidget(transition(DuckPartnerSide.first));
    await tester.pumpWidget(transition(DuckPartnerSide.second));
    var incoming = tester.widget<Transform>(
      find.byKey(const ValueKey('duck-transition-transform')),
    );
    final startX = incoming.transform.getTranslation().x;
    expect(startX, closeTo(-240, 0.1));

    await tester.pump(const Duration(milliseconds: 34));
    incoming = tester.widget<Transform>(
      find.byKey(const ValueKey('duck-transition-transform')),
    );
    expect(incoming.transform.getTranslation().x, greaterThan(startX));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('duck-transition-transform')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mood joy reaction starts and completes on its frame clock', (
    tester,
  ) async {
    var trigger = 0;
    Widget reaction() => MaterialApp(
      home: DuckJoyReaction(
        trigger: trigger,
        builder: (_, joy) => Text(
          joy.toStringAsFixed(3),
          key: const ValueKey('duck-joy-progress'),
        ),
      ),
    );

    await tester.pumpWidget(reaction());
    trigger++;
    await tester.pumpWidget(reaction());
    await tester.pump(const Duration(milliseconds: 34));
    expect(
      double.parse(
        tester
            .widget<Text>(find.byKey(const ValueKey('duck-joy-progress')))
            .data!,
      ),
      greaterThan(0),
    );
    await tester.pump(const Duration(milliseconds: 1800));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('duck-joy-progress'))).data,
      '0.000',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tamagotchi shows the locally saved partner mood by role', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': DateTime.now().millisecondsSinceEpoch,
    });

    final preferences = await SharedPreferences.getInstance();
    final profileRepository = ParticipantProfileRepository(
      preferences: preferences,
    );
    await profileRepository.saveName('first', 'Алина');
    await profileRepository.saveName('second', 'Саша');
    await profileRepository.saveCurrentSide('first');
    await SharedPreferencesPairRepository(preferences: preferences)
        .createPair('Тестовый участник');
    final moodRepository = SharedPreferencesMoodPairRepository(
      preferences: preferences,
    );
    final today = DateTime.now();
    await moodRepository.record('first', DailyMood.angry, date: today);
    await profileRepository.saveCurrentSide('second');
    await moodRepository.record('second', DailyMood.joyful, date: today);
    await profileRepository.saveCurrentSide('first');
    await preferences.setString(
      DuckOwnershipRepository.storageKey,
      jsonEncode({'date': moodDateKey(today), 'side': 'second'}),
    );

    await tester.pumpWidget(
      localizedTestApp(
        home: TamagotchiScreen(
          moodPairRepository: moodRepository,
          partnerSide: DuckPartnerSide.first,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Саша'), findsAtLeastNWidgets(1));
    expect(find.byType(DuckPetWidget), findsNothing);
    expect(
      find.byKey(const ValueKey('incoming-mood-envelope')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('incoming-mood-joyful')), findsOneWidget);

    await profileRepository.saveCurrentSide('second');
    await preferences.setString(
      DuckOwnershipRepository.storageKey,
      jsonEncode({'date': moodDateKey(today), 'side': 'first'}),
    );
    await tester.pumpWidget(
      localizedTestApp(
        home: TamagotchiScreen(
          moodPairRepository: moodRepository,
          partnerSide: DuckPartnerSide.second,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DuckPetWidget), findsNothing);
    expect(find.byKey(const ValueKey('incoming-mood-angry')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('incoming-mood-envelope')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'non-owner gets no envelope without mood and reopens it after mood changes',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'tamagotchi_name': 'Кряква',
        'tamagotchi_birth_date': DateTime.now().millisecondsSinceEpoch,
        'tamagotchi_last_fed_date': DateTime.now().millisecondsSinceEpoch,
      });
      final preferences = await SharedPreferences.getInstance();
      final profiles = ParticipantProfileRepository(preferences: preferences);
      await profiles.saveName('first', 'Алина');
      await profiles.saveName('second', 'Саша');
      await profiles.saveCurrentSide('first');
      await SharedPreferencesPairRepository(preferences: preferences)
          .createPair('Алина');
      final moods = SharedPreferencesMoodPairRepository(
        preferences: preferences,
      );
      await profiles.saveCurrentSide('second');

      await tester.pumpWidget(
        localizedTestApp(
          home: TamagotchiScreen(
            moodPairRepository: moods,
            partnerSide: DuckPartnerSide.second,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey('incoming-mood-envelope')),
        findsNothing,
      );
      expect(find.byType(DuckPetWidget), findsNothing);

      await profiles.saveCurrentSide('first');
      await moods.record('first', DailyMood.angry, date: DateTime.now());
      await profiles.saveCurrentSide('second');
      await tester.pump(const Duration(minutes: 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('incoming-mood-angry')), findsOneWidget);
      expect(find.byType(DuckPetWidget), findsNothing);

      final feedActions = find.byType(ActionChip);
      expect(feedActions, findsWidgets);
      await tester.ensureVisible(feedActions.first);
      await tester.pump();
      for (final element in feedActions.evaluate()) {
        expect((element.widget as ActionChip).onPressed, isNull);
      }

      final workButton = find.byKey(
        const ValueKey('tamagotchi-warehouse-work-button'),
      );
      await tester.ensureVisible(workButton);
      await tester.pump();
      expect(tester.widget<FilledButton>(workButton).onPressed, isNull);

      final envelope = find.byKey(const ValueKey('incoming-mood-envelope'));
      await tester.ensureVisible(envelope);
      await tester.pump();
      await tester.tap(envelope);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('mood-envelope-face')), findsOneWidget);

      await profiles.saveCurrentSide('first');
      await moods.record('first', DailyMood.joyful, date: DateTime.now());
      await profiles.saveCurrentSide('second');
      await tester.pump(const Duration(minutes: 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey('incoming-mood-joyful')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('mood-envelope-face')), findsNothing);
      await tester.ensureVisible(envelope);
      await tester.pump();
      await tester.tap(envelope);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('mood-envelope-face')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wardrobe purchase and jacket selection are persisted', (
    tester,
  ) async {
    final today = DateTime.now();
    final dateKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      GroceryWallet.storageKey: jsonEncode({
        'balance': GroceryWallet.leatherJacketPrice,
        'lastGrantDate': dateKey,
        'purchasedSkinIds': <String>[],
      }),
    });
    await _createLocalPair();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      'tamagotchi_birth_date',
      DateTime(today.year, today.month, today.day).millisecondsSinceEpoch,
    );
    await preferences.setInt(
      'tamagotchi_last_fed_date',
      DateTime(today.year, today.month, today.day).millisecondsSinceEpoch,
    );
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('Как назовём уточку? 🦆').evaluate().isNotEmpty) {
      await tester.tap(find.text('Знакомиться!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    final button = find.byKey(const ValueKey('open-duck-outfit-shop'));
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Магазин костюмов'), findsOneWidget);
    final previewCard = find.byKey(const ValueKey('duck-skin-leather-jacket'));
    await tester.tap(previewCard);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('skin-preview-leather_jacket')),
      findsOneWidget,
    );
    await tester.tap(find.text('Закрыть'));
    await tester.pump();

    final buyButton = find.byKey(const ValueKey('buy-skin-leather-jacket'));
    expect(buyButton, findsOneWidget);
    expect(tester.widget<FilledButton>(buyButton).onPressed, isNotNull);
    await tester.ensureVisible(buyButton);
    await tester.pump();
    await tester.tap(buyButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final chooseJacket = find.byKey(
      const ValueKey('select-skin-${DuckClothingShopScreen.jacketSkinId}'),
    );
    expect(chooseJacket, findsOneWidget);
    await tester.ensureVisible(chooseJacket);
    await tester.pump();
    await tester.tap(chooseJacket);
    await tester.pump();

    final storedWallet = jsonDecode(
      preferences.getString(GroceryWallet.storageKey)!,
    ) as Map<String, dynamic>;
    expect(storedWallet['balance'], 0);
    expect(storedWallet['purchasedSkinIds'], [
      DuckClothingShopScreen.jacketSkinId,
    ]);
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final duck = tester.widget<DuckPetWidget>(find.byType(DuckPetWidget).first);
    expect(
      duck.appearance.equippedItems,
      contains(DuckClothingShopScreen.jacketSkinId),
    );
    expect(
      preferences.getStringList(
        TamagotchiScreen.outfitStorageKey(DuckPartnerSide.first),
      ),
      [DuckClothingShopScreen.jacketSkinId],
    );
  });

  test(
    'animation keyframe contact sheet has complete opaque preview bounds',
    () async {
      final fileBytes = await File('assets/images/duck_animation_keyframes.png')
          .readAsBytes();
      final codec = await ui.instantiateImageCodec(fileBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final pixelData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(image.width, 1260);
      expect(image.height, 1674);
      expect(pixelData!.getUint8(3), 255);
      image.dispose();
      codec.dispose();
    },
  );

  test(
    'front sprite sheet has transparent margins and distinct pixel frames',
    () async {
      final data = await rootBundle.load('assets/images/duck_front_sheet.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(image.width, duckSpriteFrameSize * duckFrontFrameCount);
      expect(image.height, duckSpriteFrameSize);
      expect(bytes!.getUint8(3), 0);
      expect(bytes.getUint8((40 * image.width + 32) * 4 + 3), 255);

      var changedPixels = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < duckSpriteFrameSize; x++) {
          final firstPixel = (y * image.width + x) * 4;
          final blinkPixel =
              (y * image.width + duckSpriteFrameSize * 3 + x) * 4;
          for (var channel = 0; channel < 4; channel++) {
            if (bytes.getUint8(firstPixel + channel) !=
                bytes.getUint8(blinkPixel + channel)) {
              changedPixels++;
              break;
            }
          }
        }
      }
      expect(changedPixels, greaterThan(0));
      for (var frameIndex = 1; frameIndex < duckFrontFrameCount; frameIndex++) {
        var frameChanges = 0;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < duckSpriteFrameSize; x++) {
            final previousPixel =
                (y * image.width + (frameIndex - 1) * duckSpriteFrameSize + x) *
                4;
            final currentPixel =
                (y * image.width + frameIndex * duckSpriteFrameSize + x) * 4;
            for (var channel = 0; channel < 4; channel++) {
              if (bytes.getUint8(previousPixel + channel) !=
                  bytes.getUint8(currentPixel + channel)) {
                frameChanges++;
                break;
              }
            }
          }
        }
        expect(
          frameChanges,
          greaterThan(0),
          reason: 'Frame $frameIndex moves.',
        );
      }
      image.dispose();
      codec.dispose();
    },
  );

  test(
    'rear sprite has transparent margins and distinct moving poses',
    () async {
      final data = await rootBundle.load('assets/images/duck_rear_sheet.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(image.width, duckSpriteFrameSize * duckRearFrameCount);
      expect(image.height, duckSpriteFrameSize);
      expect(bytes!.getUint8(3), 0);

      for (var frameIndex = 1; frameIndex < duckRearFrameCount; frameIndex++) {
        var frameChanges = 0;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < duckSpriteFrameSize; x++) {
            final previousPixel =
                (y * image.width + (frameIndex - 1) * duckSpriteFrameSize + x) *
                4;
            final currentPixel =
                (y * image.width + frameIndex * duckSpriteFrameSize + x) * 4;
            for (var channel = 0; channel < 4; channel++) {
              if (bytes.getUint8(previousPixel + channel) !=
                  bytes.getUint8(currentPixel + channel)) {
                frameChanges++;
                break;
              }
            }
          }
        }
        expect(
          frameChanges,
          greaterThan(0),
          reason: 'Rear frame $frameIndex moves.',
        );
      }

      image.dispose();
      codec.dispose();
    },
  );

  test('sprite frame selection cycles through front and rear poses', () {
    for (var frame = 0; frame < duckFrontFrameCount; frame++) {
      expect(
        duckSpriteFrameForProgress((frame + 0.1) / duckFrontFrameCount),
        frame,
      );
    }
    expect(duckSpriteFrameForProgress(1), 0);
    for (var frame = 0; frame < duckRearFrameCount; frame++) {
      expect(
        duckSpriteFrameForProgress(
          (frame + 0.1) / duckRearFrameCount,
          view: DuckView.rear,
        ),
        frame,
      );
    }
  });

  test('duck painter handles pet, overlay, and grocery sizes', () {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    DuckPainter(
        detailSeed: 12,
        appearance: const DuckAppearance(hat: DuckHat.crown),
      )
      ..paint(canvas, const Size(240, 205))
      ..paint(canvas, const Size(150, 128))
      ..paint(canvas, const Size(112, 122));
    PixelDuckRearPainter(
      appearance: const DuckAppearance(hat: DuckHat.crown),
      gait: 0.25,
    ).paint(canvas, const Size(112, 122));
    recorder.endRecording().dispose();

    expect(DuckPainter().shouldRepaint(DuckPainter(joy: 0.8)), isTrue);
    expect(DuckPainter().shouldRepaint(DuckPainter(blink: true)), isTrue);
    expect(
      PixelDuckRearPainter().shouldRepaint(
        const PixelDuckRearPainter(gait: 0.5),
      ),
      isTrue,
    );
  });

  testWidgets('first visit creates and names the duck, feeding is persisted', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _createLocalPair();
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Как назовём уточку? 🦆'), findsOneWidget);
    await tester.tap(find.text('Знакомиться!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Кряква'), findsOneWidget);
    expect(find.textContaining('0 дней вместе с вами'), findsOneWidget);
    expect(find.textContaining('Сегодня день ухода за Кряква'), findsOneWidget);
    expect(find.text('Баланс: 0 ₴'), findsOneWidget);
    expect(find.byKey(const ValueKey('pixel-duck-sprite')), findsOneWidget);
    expect(find.text('Магазин костюмов для Кряква'), findsOneWidget);

    await tester.ensureVisible(find.text('Крошки ×0'));
    await tester.pump();
    await tester.tap(find.text('Крошки ×0'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('tamagotchi_name'), 'Кряква');
    expect(preferences.getInt('tamagotchi_birth_date'), isNotNull);
    expect(
      preferences.getInt('tamagotchi_last_fed_date'),
      preferences.getInt('tamagotchi_birth_date'),
    );
    expect(find.text('100%'), findsOneWidget);
    final shopEntry = find.byKey(const ValueKey('open-duck-outfit-shop'));
    await tester.ensureVisible(shopEntry);
    await tester.pump();
    await tester.tap(shopEntry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Магазин костюмов'), findsOneWidget);
  });

  testWidgets('overlay widget renders and responds to a tap', (tester) async {
    SharedPreferences.setMockInitialValues({'tamagotchi_name': 'Кряква'});
    await _createLocalPair();
    await tester.pumpWidget(localizedTestApp(home: const DuckOverlayWindow()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('pixel-duck-sprite')), findsOneWidget);
    await tester.tap(find.byType(GestureDetector));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('overlay stays hidden when no pair is active', (tester) async {
    SharedPreferences.setMockInitialValues({'tamagotchi_name': 'Кряква'});
    await tester.pumpWidget(localizedTestApp(home: const DuckOverlayWindow()));
    await tester.pump();

    expect(find.byKey(const ValueKey('pixel-duck-sprite')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grocery button opens the product store', (tester) async {
    SharedPreferences.setMockInitialValues({
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': DateTime.now().millisecondsSinceEpoch,
    });
    await _createLocalPair();
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final groceryButton = find.byKey(
      const ValueKey('tamagotchi-grocery-store-button'),
    );
    expect(groceryButton, findsOneWidget);
    expect(find.text('Магазин продуктов'), findsOneWidget);
    final warehouseButton = find.byKey(
      const ValueKey('tamagotchi-warehouse-work-button'),
    );
    expect(
      tester.getRect(groceryButton).center.dx,
      lessThan(tester.getRect(warehouseButton).center.dx),
    );
    expect(find.bySemanticsLabel('Магазин продуктов'), findsOneWidget);
    expect(find.bySemanticsLabel('Работа на складе'), findsOneWidget);
    await tester.ensureVisible(groceryButton);
    await tester.tap(groceryButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GroceryStoreScreen), findsOneWidget);
    expect(find.byType(WarehouseWorkScreen), findsNothing);
    expect(find.byType(DuckClothingShopScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warehouse button opens warehouse work directly', (tester) async {
    SharedPreferences.setMockInitialValues({
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': DateTime.now().millisecondsSinceEpoch,
    });
    await _createLocalPair();
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final workButton = find.byKey(
      const ValueKey('tamagotchi-warehouse-work-button'),
    );
    expect(workButton, findsOneWidget);
    expect(find.text('Работа на складе'), findsOneWidget);
    await tester.ensureVisible(workButton);
    await tester.tap(workButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(WarehouseWorkScreen), findsOneWidget);
    expect(find.byType(GroceryStoreScreen), findsNothing);
    expect(find.byType(DuckClothingShopScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collected store food is available and consumed when feeding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'pair_rooms_v1': '{}',
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_grocery_inventory': ['bread'],
    });
    final preferences = await SharedPreferences.getInstance();
    await SharedPreferencesPairRepository(preferences: preferences)
        .createPair('Тестовый участник');
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Крошки ×1'), findsOneWidget);
    await tester.ensureVisible(find.text('Крошки ×1'));
    await tester.pump();
    await tester.tap(find.text('Крошки ×1'));
    await tester.pump();

    final savedPreferences = await SharedPreferences.getInstance();
    expect(
      savedPreferences.getStringList('tamagotchi_grocery_inventory'),
      isEmpty,
    );
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('food chips use pixel sprites and keep worms in their jar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'pair_rooms_v1': '{}',
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_grocery_inventory': ['crumbs', 'watermelon', 'pizza', 'worm'],
    });
    final preferences = await SharedPreferences.getInstance();
    await SharedPreferencesPairRepository(preferences: preferences)
        .createPair('Тестовый участник');
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    for (final productId in ['crumbs', 'watermelon', 'pizza', 'worm']) {
      expect(
        find.byKey(ValueKey('pixel-product-$productId')),
        findsWidgets,
        reason: '$productId should use its pixel product sprite.',
      );
    }
    expect(find.text('Крошки ×1'), findsOneWidget);
    expect(find.text('Крошки (0)'), findsNothing);
    await tester.ensureVisible(find.text('Арбуз ×1'));
    await tester.pump();
    expect(find.text('Арбуз ×1'), findsOneWidget);
    await tester.ensureVisible(find.text('Червячки ×1'));
    await tester.pump();
    expect(find.text('Червячки ×1'), findsOneWidget);

    for (final productId in ['crumbs', 'watermelon', 'pizza']) {
      final images = tester.widgetList<Image>(
        find.byKey(ValueKey('pixel-product-$productId')),
      );
      expect(images, isNotEmpty);
      for (final image in images) {
        expect(image.image, isA<AssetImage>());
        expect(
          (image.image as AssetImage).assetName,
          'assets/images/grocery_products/$productId.png',
        );
      }
    }

    expect(
      find.byKey(const ValueKey('pixel-worm-jar-painter')),
      findsOneWidget,
      reason: 'Worms must stay in the jar in the single inventory chip.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same food cannot be served a third time in a row', (
    tester,
  ) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'pair_rooms_v1': '{}',
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': today.millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': today.millisecondsSinceEpoch,
    });
    final preferences = await SharedPreferences.getInstance();
    await SharedPreferencesPairRepository(preferences: preferences)
        .createPair('Тестовый участник');
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    Future<void> tapFood(String label) async {
      final food = find.text(label);
      await tester.ensureVisible(food);
      await tester.pump();
      final chip = find.ancestor(of: food, matching: find.byType(ActionChip));
      final onPressed = tester.widget<ActionChip>(chip).onPressed;
      expect(onPressed, isNotNull);
      onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tapFood('Крошки ×0');
    await tapFood('Крошки ×0');
    expect(preferences.getStringList('tamagotchi_recent_food_ids'), [
      'crumbs',
      'crumbs',
    ]);

    await tapFood('Крошки ×0');
    expect(find.byKey(const ValueKey('feed-variety-warning')), findsOneWidget);
    expect(preferences.getStringList('tamagotchi_recent_food_ids'), [
      'crumbs',
      'crumbs',
    ]);

    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tapFood('Крошки ×0');
    expect(find.byKey(const ValueKey('feed-variety-warning')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tapFood('Червячки ×0');
    expect(preferences.getStringList('tamagotchi_recent_food_ids'), [
      'crumbs',
      'worm',
    ]);
    await tapFood('Крошки ×0');
    expect(preferences.getStringList('tamagotchi_recent_food_ids'), [
      'worm',
      'crumbs',
    ]);
  });

  testWidgets('help opens from the app bar and closes with its cross', (
    tester,
  ) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'pair_rooms_v1': '{}',
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': today.millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': today.millisecondsSinceEpoch,
    });
    final preferences = await SharedPreferences.getInstance();
    await SharedPreferencesPairRepository(preferences: preferences)
        .createPair('Тестовый участник');
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('duck-help-button')));
    await tester.pump();
    expect(find.byKey(const ValueKey('duck-help-dialog')), findsOneWidget);
    expect(find.textContaining('Сытость уменьшается на 25%'), findsOneWidget);
    expect(find.textContaining('на третий раз'), findsOneWidget);
    expect(find.byKey(const ValueKey('duck-help-close')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('duck-help-close')));
    await tester.pump();
    expect(find.byKey(const ValueKey('duck-help-dialog')), findsNothing);
  });

  testWidgets('heart pajamas purchase and equip persist in the Tamagotchi', (
    tester,
  ) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'pair_rooms_v1': '{}',
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': today.millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': today.millisecondsSinceEpoch,
      GroceryWallet.storageKey: jsonEncode({'balance': 7500}),
    });
    await _createLocalPair();
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final shopEntry = find.byKey(const ValueKey('open-duck-outfit-shop'));
    await tester.ensureVisible(shopEntry);
    await tester.tap(shopEntry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final pajamas = find.byKey(const ValueKey('duck-skin-heart-pajamas'));
    await tester.ensureVisible(pajamas);
    await tester.pump();
    final buyPajamas = find.byKey(const ValueKey('buy-skin-heart_pajamas'));
    await tester.ensureVisible(buyPajamas);
    await tester.pump();
    await tester.tap(buyPajamas);
    await tester.pump();
    final wearButton = find.byKey(const ValueKey('select-skin-heart_pajamas'));
    await tester.ensureVisible(wearButton);
    await tester.tap(wearButton);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      preferences.getStringList(
        TamagotchiScreen.outfitStorageKey(DuckPartnerSide.first),
      ),
      ['heart_pajamas'],
    );
    expect(
      (jsonDecode(preferences.getString(GroceryWallet.storageKey)!)
          as Map<String, dynamic>)['balance'],
      0,
    );
    final duck = tester.widget<DuckPetWidget>(find.byType(DuckPetWidget).first);
    expect(duck.appearance.equippedItems, ['heart_pajamas']);
  });

  testWidgets('outfits stay with each partner side and apply on switch', (
    tester,
  ) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': today.millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': today.millisecondsSinceEpoch,
      'tamagotchi_duck_outfit': [DuckClothingShopScreen.jacketSkinId],
      TamagotchiScreen.outfitStorageKey(DuckPartnerSide.second): [
        DuckClothingShopScreen.heartPajamasSkinId,
      ],
      GroceryWallet.storageKey: jsonEncode({
        'balance': 0,
        'purchasedSkinIds': [
          DuckClothingShopScreen.jacketSkinId,
          DuckClothingShopScreen.heartPajamasSkinId,
        ],
      }),
    });
    await _createLocalPair();
    final preferences = await SharedPreferences.getInstance();

    Widget tamagotchi(DuckPartnerSide side) => localizedTestApp(
      home: TamagotchiScreen(
        key: const ValueKey('side-specific-tamagotchi'),
        partnerSide: side,
      ),
    );
    Finder duckForSide(DuckPartnerSide side) => find.byWidgetPredicate(
      (widget) => widget is DuckPetWidget && widget.key == ValueKey(side),
    );

    await tester.pumpWidget(tamagotchi(DuckPartnerSide.first));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<DuckPetWidget>(duckForSide(DuckPartnerSide.first))
          .appearance
          .equippedItems,
      [DuckClothingShopScreen.jacketSkinId],
    );
    expect(
      preferences.getStringList(
        TamagotchiScreen.outfitStorageKey(DuckPartnerSide.first),
      ),
      [DuckClothingShopScreen.jacketSkinId],
    );
    expect(preferences.getStringList('tamagotchi_duck_outfit'), isNull);

    await tester.pumpWidget(tamagotchi(DuckPartnerSide.second));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<DuckPetWidget>(duckForSide(DuckPartnerSide.second))
          .appearance
          .equippedItems,
      [DuckClothingShopScreen.heartPajamasSkinId],
    );

    await tester.pumpWidget(tamagotchi(DuckPartnerSide.first));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<DuckPetWidget>(duckForSide(DuckPartnerSide.first))
          .appearance
          .equippedItems,
      [DuckClothingShopScreen.jacketSkinId],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unpaired duck asks to create a pair without a name form', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Создать пару'), findsOneWidget);
    expect(find.byKey(const ValueKey('duck-open-pairs')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(ParticipantProfileRepository.firstNameKey),
      isNull,
    );
    expect(preferences.getString('tamagotchi_name'), isNull);
    expect(preferences.getInt('tamagotchi_birth_date'), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duck is named only after the tamagotchi tab is opened', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _createLocalPair();
    await tester.pumpWidget(
      localizedTestApp(home: const TamagotchiScreen(isActive: false)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Как назовём уточку? 🦆'), findsNothing);

    await tester.pumpWidget(
      localizedTestApp(home: const TamagotchiScreen(isActive: true)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Как назовём уточку? 🦆'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
