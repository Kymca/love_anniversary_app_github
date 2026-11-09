import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/coupon.dart';

abstract interface class DuckNotificationDriver {
  bool get isSupported;

  Future<void> initialize();

  Future<bool> requestPermission();

  Future<void> show({
    required int id,
    required String title,
    required String body,
  });
}

class DuckLocalNotificationService {
  DuckLocalNotificationService({DuckNotificationDriver? driver})
    : _driver = driver ?? _FlutterDuckNotificationDriver();

  static const channelId = 'duck_coupons_v1';
  static const channelName = 'Купоны от уточки';
  static const soundResource = 'duck_ding';
  static const soundFileName = '$soundResource.wav';
  static const iconResource = 'ic_notification_duck';

  final DuckNotificationDriver _driver;
  Future<void>? _initialization;
  static int _nextNotificationId = 0;

  Future<bool> notifyCouponActivated(Coupon coupon) async {
    return _notify(
      title: 'Уточка принесла новость!',
      body: 'Активирован купон «${coupon.title}».',
    );
  }

  Future<bool> notifyMovieMatch(String movieTitle) => _notify(
    title: 'Кино-ночь: мэтч!',
    body: 'Сегодня смотрим $movieTitle! 🍿',
  );

  Future<bool> _notify({required String title, required String body}) async {
    if (!_driver.isSupported) return false;
    final initialization = _initialization ??= _driver.initialize();
    try {
      await initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
    if (!await _driver.requestPermission()) return false;

    final id =
        (DateTime.now().millisecondsSinceEpoch + _nextNotificationId++) %
        2147483647;
    await _driver.show(id: id, title: title, body: body);
    return true;
  }
}

class _FlutterDuckNotificationDriver implements DuckNotificationDriver {
  _FlutterDuckNotificationDriver([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<void> initialize() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings(
          DuckLocalNotificationService.iconResource,
        ),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final implementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await implementation?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final implementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await implementation?.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) {
    return _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          DuckLocalNotificationService.channelId,
          DuckLocalNotificationService.channelName,
          channelDescription: 'Нежные напоминания и новости от уточки.',
          importance: Importance.high,
          priority: Priority.high,
          icon: DuckLocalNotificationService.iconResource,
          sound: RawResourceAndroidNotificationSound(
            DuckLocalNotificationService.soundResource,
          ),
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          sound: DuckLocalNotificationService.soundFileName,
        ),
      ),
    );
  }
}
