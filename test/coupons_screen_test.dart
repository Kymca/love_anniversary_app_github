import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/coupon.dart';
import 'package:love_anniversary_app/screens/coupons_screen.dart';
import 'package:love_anniversary_app/services/coupon_repository.dart';
import 'package:love_anniversary_app/services/telegram_coupon_notifier.dart';

import 'test_app.dart';

const _testCoupons = [
  Coupon(
    id: 'first',
    title: 'Первый купон',
    description: 'Подарок',
    icon: 'favorite',
    type: CouponType.oneTime,
  ),
  Coupon(
    id: 'second',
    title: 'Второй купон',
    description: 'Сюрприз',
    icon: 'movie',
    type: CouponType.oneTime,
  ),
];

class _FailingNotifier implements CouponActivationNotifier {
  var callCount = 0;

  @override
  Future<void> notifyActivated(Coupon coupon) async {
    callCount++;
    throw StateError('Notification service is unavailable.');
  }
}

void main() {
  testWidgets('scratch threshold activates once', (tester) async {
    var scratchActivations = 0;
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: CouponScratchReveal(
                onThresholdReached: () => scratchActivations++,
                onTapFallback: () => scratchActivations++,
              ),
            ),
          ),
        ),
      ),
    );

    final surface = tester.getRect(
      find.byKey(const ValueKey('scratch-surface')),
    );
    Future<void> scratchRow(double y) async {
      final gesture = await tester.startGesture(Offset(surface.left + 5, y));
      for (var x = surface.left + 20; x < surface.right; x += 20) {
        await gesture.moveTo(Offset(x, y));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
    }

    await scratchRow(surface.top + 10);
    expect(scratchActivations, 0);
    await scratchRow(surface.center.dy);
    expect(scratchActivations, 1);
    await scratchRow(surface.bottom - 10);
    expect(scratchActivations, 1);
    await tester.dragFrom(
      Offset(surface.left + 5, surface.center.dy),
      Offset(surface.right - 5, 0),
    );
    expect(scratchActivations, 1);
  });

  testWidgets('scratch surface supports tap fallback', (tester) async {
    var activations = 0;
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: CouponScratchReveal(
                onThresholdReached: () => activations++,
                onTapFallback: () => activations++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('scratch-surface')));
    expect(activations, 1);
  });

  testWidgets(
    'notification exception warns but does not undo coupon activation',
    (tester) async {
      final repository = InMemoryCouponRepository(_testCoupons);
      final notifier = _FailingNotifier();
      var callbackCount = 0;
      await tester.pumpWidget(
        localizedTestApp(
          home: CouponsScreen(
            repository: repository,
            notifier: notifier,
            onActivated: (_) => callbackCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Активировать').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(callbackCount, 1);
      expect(notifier.callCount, 1);
      final coupons = await repository.load();
      expect(coupons.first.isActivated, isTrue);
      expect(coupons.last.isActivated, isFalse);
      expect(find.text('Уже использован'), findsOneWidget);
      expect(
        find.text('Купон активирован, но уведомление не удалось показать.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('empty repository is provisioned with the daily coupon', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        home: CouponsScreen(repository: InMemoryCouponRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Маленькое желание дня'), findsOneWidget);
    expect(
      find.text('Выбери приятный сюрприз для нас сегодня.'),
      findsOneWidget,
    );
  });

  testWidgets('daily coupon title and description use Ukrainian localization', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        locale: const Locale('uk'),
        home: CouponsScreen(repository: InMemoryCouponRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Маленьке бажання дня'), findsOneWidget);
    expect(
      find.text('Обери приємний сюрприз для нас сьогодні.'),
      findsOneWidget,
    );
    expect(find.text('Выбери приятный сюрприз для нас сегодня.'), findsNothing);
  });
}
