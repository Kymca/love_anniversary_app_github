import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:love_anniversary_app/main.dart';
import 'package:love_anniversary_app/models/coupon.dart';
import 'package:love_anniversary_app/services/coupon_repository.dart';
import 'package:love_anniversary_app/screens/secret_notes_screen.dart';
import 'package:love_anniversary_app/screens/coupons_screen.dart';
import 'package:love_anniversary_app/screens/tamagotchi_screen.dart';
import 'package:love_anniversary_app/services/duck_local_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  test('relationship duration uses calendar years and months', () {
    final elapsed = RelationshipDuration.since(
      relationshipStartDate,
      DateTime(2025, 1, 15, 23, 35, 42),
    );

    expect(elapsed.years, 1);
    expect(elapsed.months, 2);
    expect(elapsed.days, 2);
    expect(elapsed.hours, 3);
    expect(elapsed.minutes, 5);
    expect(elapsed.seconds, 42);
  });

  test('duration is zero before the relationship begins', () {
    final elapsed = RelationshipDuration.since(
      relationshipStartDate,
      DateTime(2023, 11, 13, 20, 29, 59),
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
    expect(find.text('С 13 ноября 2023 года • 20:30'), findsOneWidget);
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

  testWidgets('paired duck name replaces the Tamagotchi navigation label', (
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

    expect(find.byKey(const ValueKey('navigation-Кряква')), findsOneWidget);
    expect(find.byKey(const ValueKey('navigation-Тамагочи')), findsNothing);
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
    expect(
      find.textContaining('Дані пари зберігаються лише на цьому пристрої.'),
      findsOneWidget,
    );
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
    expect(find.textContaining('LAN-сервер не настроен.'), findsOneWidget);
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
