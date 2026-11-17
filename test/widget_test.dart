import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:love_anniversary_app/main.dart';
import 'package:love_anniversary_app/models/coupon.dart';
import 'package:love_anniversary_app/services/coupon_repository.dart';
import 'package:love_anniversary_app/screens/secret_notes_screen.dart';
import 'package:love_anniversary_app/screens/coupons_screen.dart';
import 'package:love_anniversary_app/screens/tamagotchi_screen.dart';
import 'package:love_anniversary_app/services/duck_local_notification_service.dart';
import 'package:love_anniversary_app/services/participant_profile_repository.dart';
import 'package:love_anniversary_app/services/pair_repository.dart';
import 'package:love_anniversary_app/services/telegram_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  late TelegramChatService bundledChatService;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    bundledChatService = TelegramChatService(
      bundle: _StringAssetBundle(_syntheticChatExport()),
      preferences: await SharedPreferences.getInstance(),
    );
    await bundledChatService.getDailySnippet();
  });

  test('relationship duration uses calendar years and months', () {
    final elapsed = RelationshipDuration.since(
      relationshipStartDate,
      DateTime(2025, 1, 15, 23, 35, 42),
    );

    expect(elapsed.years, 1);
    expect(elapsed.months, 2);
    expect(elapsed.days, 1);
    expect(elapsed.hours, 23);
    expect(elapsed.minutes, 35);
    expect(elapsed.seconds, 42);
  });

  test('duration is zero before the relationship begins', () {
    final elapsed = RelationshipDuration.since(
      relationshipStartDate,
      DateTime(2023, 11, 13, 23, 59, 59),
    );

    expect(elapsed.years, 0);
    expect(elapsed.months, 0);
    expect(elapsed.days, 0);
    expect(elapsed.hours, 0);
    expect(elapsed.minutes, 0);
    expect(elapsed.seconds, 0);
  });

  testWidgets('home screen shows the relationship timer and updates seconds', (
    tester,
  ) async {
    var now = DateTime(2025, 1, 15, 23, 35, 42);
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(body: AnniversaryHomePage(clock: () => now)),
      ),
    );

    expect(find.text('НАША ИСТОРИЯ'), findsOneWidget);
    expect(find.text('С 14 ноября 2023 года'), findsOneWidget);
    expect(find.text('И это только начало ♥'), findsOneWidget);

    final secondsValue = find.descendant(
      of: find.byKey(const ValueKey('seconds-card')),
      matching: find.byType(Text),
    );
    final initialValue = int.parse(
      tester.widget<Text>(secondsValue.first).data!,
    );
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    final nextValue = (initialValue + 1) % 60;
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('seconds-card')),
        matching: find.byKey(ValueKey(nextValue)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('inactive home does not run its one-second timer', (
    tester,
  ) async {
    var now = DateTime(2025, 1, 15, 23, 35, 42);
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: AnniversaryHomePage(clock: () => now, isActive: false),
        ),
      ),
    );
    final secondsValue = find.descendant(
      of: find.byKey(const ValueKey('seconds-card')),
      matching: find.byType(Text),
    );
    final initialValue = tester.widget<Text>(secondsValue.first).data;

    now = now.add(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));

    expect(tester.widget<Text>(secondsValue.first).data, initialValue);
  });

  testWidgets('inactive home pauses the pulsing heart animation', (
    tester,
  ) async {
    var isActive = true;
    Widget home() => localizedTestApp(
      home: Scaffold(
        body: AnniversaryHomePage(
          clock: () => DateTime(2025, 1, 15, 23, 35, 42),
          isActive: isActive,
        ),
      ),
    );

    await tester.pumpWidget(home());
    await tester.pump(const Duration(milliseconds: 450));
    double pulseScale() => tester
        .widget<ScaleTransition>(
          find.byKey(const ValueKey('home-pulsing-heart-scale')),
        )
        .scale
        .value;
    final activeScale = pulseScale();

    isActive = false;
    await tester.pumpWidget(home());
    final pausedScale = pulseScale();
    await tester.pump(const Duration(seconds: 2));

    expect(activeScale, isNot(0.94));
    expect(pulseScale(), pausedScale);
  });

  testWidgets('home uses the current participant name from the shared pair', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final profileRepository = ParticipantProfileRepository(
      preferences: preferences,
    );
    await profileRepository.saveCurrentSide('second');
    final pairRepository = SharedPreferencesPairRepository(
      preferences: preferences,
    );
    final pair = await pairRepository.createPair('Алина');
    await pairRepository.joinPair('Руслан', pair.code);

    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: AnniversaryHomePage(
            profileRepository: profileRepository,
            pairRepository: pairRepository,
          ),
        ),
      ),
    );
    for (var index = 0; index < 5; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Руслан'), findsOneWidget);
    expect(find.text('Алина'), findsNothing);
  });

  testWidgets('home loads a daily quote from a synthetic chat export', (
    tester,
  ) async {
    final snippet = await bundledChatService.getDailySnippet();
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: AnniversaryHomePage(
            clock: () => DateTime(2026, 11, 14, 20, 30),
            memoryService: bundledChatService,
          ),
        ),
      ),
    );
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('С 14 ноября 2023 года'), findsOneWidget);
    expect(find.text('Кря-цитата дня'), findsOneWidget);
    expect(find.text(snippet.messages.first.text), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-loading')), findsNothing);
    expect(find.byKey(const ValueKey('memory-empty')), findsNothing);
    expect(find.byTooltip('Добавить в избранное'), findsOneWidget);
    expect(find.text('Подходящего воспоминания пока нет.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final anniversaryTime in [
    DateTime(2026, 11, 14),
    DateTime(2026, 11, 14, 17, 36),
  ]) {
    testWidgets(
      'home counts the anniversary from midnight at $anniversaryTime',
      (tester) async {
        await tester.pumpWidget(
          localizedTestApp(
            home: Scaffold(
              body: AnniversaryHomePage(
                clock: () => anniversaryTime,
                memoryService: bundledChatService,
              ),
            ),
          ),
        );

        expect(find.text('С 14 ноября 2023 года'), findsOneWidget);
        expect(find.text('3 года'), findsOneWidget);
        expect(find.text('0 месяцев'), findsOneWidget);
        expect(find.text('0 дней'), findsOneWidget);
      },
    );
  }

  test(
    'relationship anniversary starts the next year with zero extra days',
    () {
      final elapsed = RelationshipDuration.since(
        relationshipStartDate,
        DateTime(2026, 11, 14),
      );

      expect(elapsed.years, 3);
      expect(elapsed.months, 0);
      expect(elapsed.days, 0);
      expect(elapsed.hours, 0);
      expect(elapsed.minutes, 0);
      expect(elapsed.seconds, 0);
    },
  );

  test('relationship anniversary begins at midnight regardless of old display time', () {
    final elapsed = RelationshipDuration.since(
      relationshipStartDate,
      DateTime(2026, 11, 14, 17, 36),
    );

    expect(elapsed.years, 3);
    expect(elapsed.months, 0);
    expect(elapsed.days, 0);
    expect(elapsed.hours, 17);
    expect(elapsed.minutes, 36);
  });

  testWidgets('home pairs bubble opens the pairs destination', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LoveAnniversaryApp());
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('home-pairs-bubble')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Создать пару'), findsOneWidget);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 6);
    expect(find.byKey(const ValueKey('navigation-Пары')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home profile name is saved for the current participant', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LoveAnniversaryApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('home-profile-name')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Алина');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(ParticipantProfileRepository.firstNameKey),
      'Алина',
    );
    expect(find.text('Алина'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-pairs-bubble')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final createPairButton = find.widgetWithText(FilledButton, 'Создать пару');
    expect(tester.widget<FilledButton>(createPairButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('romantic navigation fits a compact screen without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': DateTime.now().millisecondsSinceEpoch,
    });

    await tester.pumpWidget(const LoveAnniversaryApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull, reason: 'home layout overflowed');
    await tester.tap(find.text('Тамагочи'));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'tab switch overflowed');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Совместный тамагочи'), findsOneWidget);
    final layoutError = tester.takeException();
    expect(layoutError, isNull, reason: '$layoutError');
    await tester.tap(find.text('Купоны'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Купоны на желания'), findsOneWidget);
    final couponsLayoutError = tester.takeException();
    expect(couponsLayoutError, isNull, reason: '$couponsLayoutError');
  });

  testWidgets(
    'coupon activation stays successful when local notifications are unavailable',
    (tester) async {
      await _preparePairedProfile();
      final repository = InMemoryCouponRepository([_notificationTestCoupon]);
      await tester.pumpWidget(
        LoveAnniversaryApp(
          couponRepository: repository,
          duckNotificationService: DuckLocalNotificationService(
            driver: _UnavailableDuckNotificationDriver(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _activateCoupon(tester);

      expect(
        find.text('Купон активирован! Уточка несёт тебе радость!'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Купон активирован. Не удалось показать локальное уведомление.',
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Купон активирован. Локальные уведомления отключены или недоступны.',
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);
      expect(
        (await repository.load())
            .singleWhere((coupon) => coupon.id == _notificationTestCoupon.id)
            .isActivated,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'local notification exceptions are logged without an error snackbar',
    (tester) async {
      await _preparePairedProfile();
      final reportedErrors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = reportedErrors.add;
      addTearDown(() => FlutterError.onError = previousErrorHandler);

      await tester.pumpWidget(
        LoveAnniversaryApp(
          couponRepository: InMemoryCouponRepository([_notificationTestCoupon]),
          duckNotificationService: DuckLocalNotificationService(
            driver: _FailingDuckNotificationDriver(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _activateCoupon(tester);

      FlutterError.onError = previousErrorHandler;
      expect(
        find.text('Купон активирован! Уточка несёт тебе радость!'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Купон активирован. Не удалось показать локальное уведомление.',
        ),
        findsNothing,
      );
      expect(reportedErrors, hasLength(1));
      expect(reportedErrors.single.exception, isA<StateError>());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unverified local pair does not replace the Tamagotchi label', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'pair_rooms_v1': '{"1234":{"code":"1234","members":[{"name":"Алина"}]}}',
      'active_pair_code_v1': '1234',
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': DateTime.now().millisecondsSinceEpoch,
    });
    await tester.pumpWidget(const LoveAnniversaryApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('navigation-Тамагочи')), findsOneWidget);
    expect(find.byKey(const ValueKey('navigation-Кряква')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'portrait layout keeps content visible and navigation at bottom',
    (tester) async {
      tester.view.physicalSize = const Size(486, 1026);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const LoveAnniversaryApp());
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Вместе — с каждым мгновением'), findsOneWidget);
      final navRect = tester.getRect(
        find.byKey(const ValueKey('main-navigation')),
      );
      final selectedRect = tester.getRect(
        find.byKey(const ValueKey('navigation-Наша история')),
      );
      expect(navRect.height, lessThan(80));
      expect(navRect.bottom, greaterThan(900));
      expect(selectedRect.height, lessThan(70));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('language selector switches to Ukrainian and persists locale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': DateTime.now().millisecondsSinceEpoch,
    });
    await tester.pumpWidget(const LoveAnniversaryApp());
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Вместе — с каждым мгновением'), findsOneWidget);
    await tester.tap(find.byTooltip('Українська'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Разом — з кожною миттю'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-pairs-bubble')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final createPairButton = find.widgetWithText(FilledButton, 'Створити пару');
    expect(tester.widget<FilledButton>(createPairButton).onPressed, isNotNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_locale'), 'uk');
    expect(tester.takeException(), isNull);
  });

  testWidgets('secret notes destination selects its tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(localizedTestApp(home: const SecretNotesScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Секретные заметки'), findsOneWidget);
    expect(find.text('Капсула времени'), findsOneWidget);
    expect(find.text('Настроение вдвоём'), findsNothing);
    expect(find.text('Открыть раздел «Пары»'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Открыть архив открыток'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Открыть архив открыток'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('postcards tab opens the archive', (tester) async {
    SharedPreferences.setMockInitialValues({
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': DateTime.now().millisecondsSinceEpoch,
    });
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const LoveAnniversaryApp());
    await tester.tap(find.byKey(const ValueKey('navigation-Открытки')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 5);
    expect(
      find.text(
        'Здесь хранятся действительно отправленные и полученные открытки.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Синхронизация открыток с сервером пока не подключена.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('coupon activation triggers messenger reaction callback', (
    tester,
  ) async {
    final repository = InMemoryCouponRepository([
      const Coupon(
        id: 'messenger-test',
        title: 'Купон-поздравление',
        description: 'Сюрприз',
        icon: 'favorite',
        type: CouponType.oneTime,
      ),
    ]);
    final notificationDriver = _TestDuckNotificationDriver();
    final notificationService = DuckLocalNotificationService(
      driver: notificationDriver,
    );
    Coupon? activatedCoupon;
    await tester.pumpWidget(
      localizedTestApp(
        home: CouponsScreen(
          repository: repository,
          onActivated: (coupon) async {
            activatedCoupon = coupon;
            await notificationService.notifyCouponActivated(coupon);
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Активировать').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(activatedCoupon?.id, 'messenger-test');
    expect(notificationDriver.notifications, hasLength(1));
    expect(
      notificationDriver.notifications.single.body,
      contains('Купон-поздравление'),
    );
    expect(
      (await repository.load())
          .singleWhere((coupon) => coupon.id == 'messenger-test')
          .isActivated,
      isTrue,
    );
    SharedPreferences.setMockInitialValues({
      'pair_rooms_v1': '{"1234":{"code":"1234","members":[{"name":"Алина"}]}}',
      'active_pair_code_v1': '1234',
      'tamagotchi_name': 'Кряква',
      'tamagotchi_birth_date': DateTime.now().millisecondsSinceEpoch,
      'tamagotchi_last_fed_date': DateTime.now().millisecondsSinceEpoch,
    });
    await tester.pumpWidget(localizedTestApp(home: const TamagotchiScreen()));
    await tester.pump();
    await tester.pumpWidget(
      localizedTestApp(home: const TamagotchiScreen(messengerEventId: 1)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Купон активирован! Уточка несёт тебе радость!'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coupon-messenger-bubble')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

const _notificationTestCoupon = Coupon(
  id: 'local-notification-test',
  title: 'Проверка уведомления',
  description: 'Подарок',
  icon: 'favorite',
  type: CouponType.oneTime,
);

Future<void> _preparePairedProfile() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await ParticipantProfileRepository(preferences: preferences)
      .saveName('first', 'Алина');
  await SharedPreferencesPairRepository(preferences: preferences)
      .createPair('Алина');
  final today = DateTime.now();
  await preferences.setInt(
    'tamagotchi_birth_date',
    DateTime(today.year, today.month, today.day).millisecondsSinceEpoch,
  );
  await preferences.setInt(
    'tamagotchi_last_fed_date',
    DateTime(today.year, today.month, today.day).millisecondsSinceEpoch,
  );
}

Future<void> _activateCoupon(WidgetTester tester) async {
  await tester.tap(find.text('Купоны'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Активировать').first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 300));
}

class _UnavailableDuckNotificationDriver implements DuckNotificationDriver {
  @override
  bool get isSupported => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {}
}

class _FailingDuckNotificationDriver implements DuckNotificationDriver {
  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {
    throw StateError('Notification plugin failed to initialize.');
  }

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {}
}

class _TestDuckNotificationDriver implements DuckNotificationDriver {
  final notifications = <_TestNotification>[];

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    notifications.add(_TestNotification(title: title, body: body));
  }
}

class _TestNotification {
  const _TestNotification({required this.title, required this.body});

  final String title;
  final String body;
}

String _syntheticChatExport() => jsonEncode({
  'id': 42,
  'name': 'Synthetic chat',
  'type': 'personal_chat',
  'messages': [
    for (var index = 0; index < 12; index++)
      {
        'id': index + 1,
        'type': 'message',
        'date': '2024-01-01T12:${index.toString().padLeft(2, '0')}:00',
        'from': index.isEven ? 'Алина' : 'Руслан',
        'from_id': index.isEven ? 'user-1' : 'user-2',
        'text': 'Synthetic friendly message $index',
      },
  ],
});

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
}
