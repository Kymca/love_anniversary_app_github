import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppSoundEvent {
  rouletteTick,
  rouletteStopped,
  couponActivated,
  partnerCouponActivated,
  couponAvailable,
  postcardReceived,
  duckArrived,
}

class AppSoundService {
  const AppSoundService._();

  static Future<void> play(AppSoundEvent event) async {
    switch (event) {
      case AppSoundEvent.rouletteTick:
        await _playSystemSound(SystemSoundType.click);
        break;
      case AppSoundEvent.rouletteStopped:
        await _playSystemSound(SystemSoundType.click);
        await _playHaptic(HapticFeedback.mediumImpact);
        break;
      case AppSoundEvent.partnerCouponActivated:
        await _playSystemSound(SystemSoundType.alert);
        await _playHaptic(HapticFeedback.lightImpact);
        break;
      case AppSoundEvent.couponActivated:
        await _playSystemSound(SystemSoundType.click);
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await _playSystemSound(SystemSoundType.click);
        await _playHaptic(HapticFeedback.lightImpact);
        break;
      case AppSoundEvent.couponAvailable:
        await _playSystemSound(SystemSoundType.click);
        await Future<void>.delayed(const Duration(milliseconds: 110));
        await _playSystemSound(SystemSoundType.alert);
        break;
      case AppSoundEvent.postcardReceived:
        await _playSystemSound(SystemSoundType.alert);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await _playSystemSound(SystemSoundType.click);
        break;
      case AppSoundEvent.duckArrived:
        await _playSystemSound(SystemSoundType.click);
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await _playSystemSound(SystemSoundType.alert);
        await _playHaptic(HapticFeedback.mediumImpact);
        break;
    }
  }

  static Future<void> _playSystemSound(SystemSoundType sound) async {
    try {
      await SystemSound.play(sound);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app sound feedback',
          context: ErrorDescription('while playing a system sound'),
        ),
      );
    }
  }

  static Future<void> _playHaptic(Future<void> Function() haptic) async {
    try {
      await haptic();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app sound feedback',
          context: ErrorDescription('while playing haptic feedback'),
        ),
      );
    }
  }
}

class RouletteSpinSound {
  bool _isActive = false;
  int _tick = 0;
  Timer? _timer;

  void start() {
    cancel();
    _isActive = true;
    _tick = 0;
    _playTick();
  }

  void _playTick() {
    if (!_isActive) return;
    unawaited(AppSoundService.play(AppSoundEvent.rouletteTick));
    final delayMilliseconds = 80 + (_tick < 10 ? _tick * 22 : 220);
    _tick++;
    _timer = Timer(
      Duration(milliseconds: delayMilliseconds),
      _playTick,
    );
  }

  void finish() {
    cancel();
    unawaited(AppSoundService.play(AppSoundEvent.rouletteStopped));
  }

  void cancel() {
    _isActive = false;
    _timer?.cancel();
    _timer = null;
  }
}
