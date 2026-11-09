import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/coupon.dart';
import 'package:love_anniversary_app/services/duck_local_notification_service.dart';

void main() {
  const coupon = Coupon(
    id: 'cinema',
    title: 'Кино-вечер',
    description: 'Выбираем фильм вместе.',
    icon: 'movie',
    type: CouponType.oneTime,
  );

  test(
    'coupon notification requests permission and shows a duck message',
    () async {
      final driver = _FakeDuckNotificationDriver();
      final service = DuckLocalNotificationService(driver: driver);

      expect(await service.notifyCouponActivated(coupon), isTrue);
      expect(driver.initializeCount, 1);
      expect(driver.permissionCount, 1);
      expect(driver.notifications, hasLength(1));
      expect(driver.notifications.single.title, 'Уточка принесла новость!');
      expect(
        driver.notifications.single.body,
        'Активирован купон «Кино-вечер».',
      );
    },
  );

  test('denied permission does not display a notification', () async {
    final driver = _FakeDuckNotificationDriver(permissionGranted: false);
    final service = DuckLocalNotificationService(driver: driver);

    expect(await service.notifyCouponActivated(coupon), isFalse);
    expect(driver.notifications, isEmpty);
  });

  test('shares one initialization across notifications', () async {
    final driver = _FakeDuckNotificationDriver();
    final service = DuckLocalNotificationService(driver: driver);

    await service.notifyCouponActivated(coupon);
    await service.notifyCouponActivated(coupon);

    expect(driver.initializeCount, 1);
    expect(driver.permissionCount, 2);
    expect(driver.notifications, hasLength(2));
    expect(driver.notifications[0].id, isNot(driver.notifications[1].id));
  });

  test(
    'movie match uses local notification chime with matched title',
    () async {
      final driver = _FakeDuckNotificationDriver();
      final service = DuckLocalNotificationService(driver: driver);

      expect(await service.notifyMovieMatch('Рататуй'), isTrue);
      expect(driver.notifications.single.title, 'Кино-ночь: мэтч!');
      expect(driver.notifications.single.body, contains('Рататуй'));
    },
  );

  test('bundles short PCM chime for Android and iOS', () async {
    final androidSound = File(
      'android${Platform.pathSeparator}app${Platform.pathSeparator}src'
      '${Platform.pathSeparator}main${Platform.pathSeparator}res'
      '${Platform.pathSeparator}raw${Platform.pathSeparator}duck_ding.wav',
    );
    final iosSound = File(
      'ios${Platform.pathSeparator}Runner${Platform.pathSeparator}duck_ding.wav',
    );
    for (final sound in [androidSound, iosSound]) {
      final bytes = await sound.readAsBytes();
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE');
      expect(bytes.length, lessThan(100000));
    }

    expect(DuckLocalNotificationService.channelId, 'duck_coupons_v1');
    expect(
      DuckLocalNotificationService.soundFileName,
      '${DuckLocalNotificationService.soundResource}.wav',
    );
    expect(DuckLocalNotificationService.iconResource, 'ic_notification_duck');
  });
}

class _FakeDuckNotificationDriver implements DuckNotificationDriver {
  _FakeDuckNotificationDriver({this.permissionGranted = true});

  final bool permissionGranted;
  final notifications = <_CapturedNotification>[];
  int initializeCount = 0;
  int permissionCount = 0;

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {
    initializeCount++;
  }

  @override
  Future<bool> requestPermission() async {
    permissionCount++;
    return permissionGranted;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    notifications.add(_CapturedNotification(id: id, title: title, body: body));
  }
}

class _CapturedNotification {
  const _CapturedNotification({
    required this.id,
    required this.title,
    required this.body,
  });

  final int id;
  final String title;
  final String body;
}
