import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PairPushRegistrationService {
  PairPushRegistrationService._(this._client, this._messaging);

  final SupabaseClient _client;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  static Future<PairPushRegistrationService?> initialize({
    required SupabaseClient client,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return null;

    final apiKey = const String.fromEnvironment('FIREBASE_API_KEY');
    final projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID');
    final senderId = const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    );
    final appId = Platform.isAndroid
        ? const String.fromEnvironment('FIREBASE_ANDROID_APP_ID')
        : const String.fromEnvironment('FIREBASE_IOS_APP_ID');
    if (apiKey.isEmpty || projectId.isEmpty || senderId.isEmpty || appId.isEmpty) {
      return null;
    }

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
      ),
    );
    final service = PairPushRegistrationService._(
      client,
      FirebaseMessaging.instance,
    );
    await service.start();
    return service;
  }

  Future<void> start() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }
    if (Platform.isAndroid) await _createAndroidChannel();
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (_) => unawaited(_registerSafely()),
      onError: (Object error, StackTrace stackTrace) {
        _reportError(error, stackTrace);
      },
    );
    _authSubscription = _client.auth.onAuthStateChange.listen(
      (state) {
        if (state.session != null) unawaited(_registerSafely());
      },
      onError: (Object error, StackTrace stackTrace) {
        _reportError(error, stackTrace);
      },
    );
    await _registerSafely();
  }

  Future<void> _createAndroidChannel() async {
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'pair_events_v1',
        'События пары',
        description: 'Открытки, купоны и события уточки.',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('duck_ding'),
      ),
    );
  }

  Future<void> _registerCurrentToken() async {
    if (_client.auth.currentUser == null) return;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    final response = await _client.functions.invoke(
      'register-push-device',
      body: {'token': token, 'platform': Platform.isAndroid ? 'android' : 'ios'},
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        'Push device registration failed with HTTP ${response.status}.',
      );
    }
  }

  Future<void> _registerSafely() async {
    try {
      await _registerCurrentToken();
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  void _reportError(Object error, [StackTrace? stackTrace]) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace ?? StackTrace.current,
        library: 'pair push registration',
        context: ErrorDescription('while registering an FCM device token'),
      ),
    );
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
  }
}
