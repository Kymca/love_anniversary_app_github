import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_release.dart';
import 'supabase_backend.dart';

abstract interface class AppUpdateService {
  Future<AppRelease?> checkForUpdate();

  Future<void> installUpdate(AppRelease release);
}

class SupabaseAppUpdateService implements AppUpdateService {
  SupabaseAppUpdateService({
    required this.client,
    http.Client? httpClient,
    MethodChannel? channel,
  }) : _httpClient = httpClient ?? http.Client(),
       _channel = channel ?? const MethodChannel('love_anniversary_app/app');

  static const _maxApkBytes = 300 * 1024 * 1024;
  static const _packageName = AppRelease.expectedPackageName;

  final SupabaseClient client;
  final http.Client _httpClient;
  final MethodChannel _channel;

  @override
  Future<AppRelease?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    final installed = await _channel.invokeMapMethod<String, dynamic>(
      'getAppVersion',
    );
    final supportedAbisValue = installed?['supportedAbis'];
    if (installed == null ||
        installed['packageName'] != _packageName ||
        installed['versionCode'] is! int ||
        supportedAbisValue is! List ||
        supportedAbisValue.isEmpty ||
        supportedAbisValue.any((abi) => abi is! String || abi.isEmpty)) {
      throw StateError('Unable to read the installed Android app version.');
    }

    final installedVersionCode = installed['versionCode'] as int;
    final supportedAbis = List<String>.from(supportedAbisValue);
    final response = await client.functions.invoke(
      'app-update-check',
      body: {
        'versionCode': installedVersionCode,
        'packageName': _packageName,
        'supportedAbis': supportedAbis,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('App update check failed (${response.status}).');
    }
    if (response.data is! Map) {
      throw const FormatException('Invalid app update response.');
    }

    return AppRelease.fromUpdateResponse(
      Map<String, dynamic>.from(response.data as Map),
      supabaseBaseUrl: Uri.parse(supabaseUrl),
      installedVersionCode: installedVersionCode,
    );
  }

  @override
  Future<void> installUpdate(AppRelease release) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('APK updates are only supported on Android.');
    }

    final allowed =
        await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    if (!allowed) {
      await _channel.invokeMethod<void>('openUnknownSourcesSettings');
      throw const AppInstallPermissionRequired();
    }

    final temp = await getTemporaryDirectory();
    final updateDirectory = Directory(
      '${temp.path}${Platform.pathSeparator}app_updates',
    );
    await updateDirectory.create(recursive: true);
    final apkFile = File(
      '${updateDirectory.path}${Platform.pathSeparator}'
      'release-${release.versionCode}-${release.abi}.apk',
    );

    try {
      final request = http.Request('GET', release.downloadUrl);
      request.headers['Accept'] = 'application/vnd.android.package-archive';
      request.followRedirects = false;
      final response = await _httpClient.send(request);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('APK download failed (${response.statusCode}).');
      }

      final output = apkFile.openWrite();
      var receivedBytes = 0;
      try {
        await for (final chunk in response.stream) {
          receivedBytes += chunk.length;
          if (receivedBytes > _maxApkBytes) {
            throw const HttpException('APK exceeds the allowed size.');
          }
          output.add(chunk);
        }
        await output.close();
      } catch (_) {
        await output.close();
        rethrow;
      }

      if (receivedBytes == 0) {
        throw const HttpException('The downloaded APK is empty.');
      }

      final digest = await sha256.bind(apkFile.openRead()).first;
      if (digest.toString() != release.sha256) {
        throw const FormatException('Downloaded APK checksum mismatch.');
      }

      final result = await _channel.invokeMethod<String>('installApk', {
        'path': apkFile.path,
      });
      if (result == 'permission_required') {
        await _channel.invokeMethod<void>('openUnknownSourcesSettings');
        throw const AppInstallPermissionRequired();
      }
      if (result != 'started') {
        throw StateError('Android did not open the package installer.');
      }
    } catch (_) {
      if (await apkFile.exists()) await apkFile.delete();
      rethrow;
    }
  }
}

class AppInstallPermissionRequired implements Exception {
  const AppInstallPermissionRequired();
}
