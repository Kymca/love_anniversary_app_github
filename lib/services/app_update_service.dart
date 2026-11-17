import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const appReleasePackageName = 'com.example.love_anniversary_app';
const appReleaseBucket = 'app-releases';
const _supabaseUrl = 'https://xbbybirzhmhlsnvmyvxa.supabase.co';
const _maximumApkBytes = 512 * 1024 * 1024;
const _updateFunctionName = 'app-update-check';

class AppUpdate {
  const AppUpdate({
    required this.versionCode,
    required this.sha256,
    required this.apkObjectPath,
    required this.versionName,
    required this.packageName,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  final int versionCode;
  final String sha256;
  final String apkObjectPath;
  final String versionName;
  final String packageName;
  final String releaseNotes;
  final String downloadUrl;

  factory AppUpdate.fromFunctionResponse(Map<String, dynamic> json) {
    final versionCode = json['versionCode'];
    final checksum = json['sha256'];
    final objectPath = json['apkObjectPath'];
    final versionName = json['versionName'];
    final packageName = json['packageName'];
    final releaseNotes = json['releaseNotes'];
    final downloadUrl = json['downloadUrl'];

    if (versionCode is! int || versionCode < 1) {
      throw const FormatException('Update has an invalid version code.');
    }
    if (checksum is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(checksum)) {
      throw const FormatException('Update has an invalid SHA-256 hash.');
    }
    if (objectPath != 'releases/$versionCode/app-release.apk') {
      throw const FormatException('Update has an invalid APK object path.');
    }
    if (versionName is! String || versionName.isEmpty) {
      throw const FormatException('Update has no version name.');
    }
    if (packageName != appReleasePackageName) {
      throw const FormatException('Update is for a different Android package.');
    }
    if (releaseNotes is! String) {
      throw const FormatException('Update has invalid release notes.');
    }
    if (downloadUrl is! String ||
        !_isTrustedSignedDownloadUrl(downloadUrl, versionCode)) {
      throw const FormatException('Update has an untrusted download URL.');
    }

    return AppUpdate(
      versionCode: versionCode,
      sha256: checksum.toLowerCase(),
      apkObjectPath: objectPath,
      versionName: versionName,
      packageName: packageName,
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
    );
  }

  bool isNewerThan(int installedVersionCode) =>
      versionCode > installedVersionCode;

  static bool _isTrustedSignedDownloadUrl(String value, int versionCode) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != Uri.parse(_supabaseUrl).host ||
        uri.userInfo.isNotEmpty ||
        (uri.port != 443 && uri.port != 0) ||
        uri.queryParameters['token']?.isNotEmpty != true ||
        uri.fragment.isNotEmpty) {
      return false;
    }
    return uri.pathSegments.length == 8 &&
        uri.pathSegments[0] == 'storage' &&
        uri.pathSegments[1] == 'v1' &&
        uri.pathSegments[2] == 'object' &&
        uri.pathSegments[3] == 'sign' &&
        uri.pathSegments[4] == appReleaseBucket &&
        uri.pathSegments[5] == 'releases' &&
        uri.pathSegments[6] == '$versionCode' &&
        uri.pathSegments[7] == 'app-release.apk';
  }
}

abstract interface class AppUpdateService {
  Future<AppUpdate?> checkForUpdate();

  Future<bool> downloadAndInstall(AppUpdate update);
}

class SupabaseAppUpdateService implements AppUpdateService {
  SupabaseAppUpdateService({
    this.channel = const MethodChannel('love_anniversary_app/app'),
    this.client,
  });

  final MethodChannel channel;
  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  @override
  Future<AppUpdate?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    final installed = await channel.invokeMapMethod<String, dynamic>(
      'getAppVersion',
    );
    final installedVersionCode = int.tryParse(
      installed?['buildNumber']?.toString() ?? '',
    );
    if (installedVersionCode == null) {
      throw const FormatException('Installed app version is unavailable.');
    }

    final response = await _supabase.functions.invoke(
      _updateFunctionName,
      body: {
        'versionCode': installedVersionCode,
        'packageName': appReleasePackageName,
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Update check returned an invalid response.');
    }
    final responseJson = Map<String, dynamic>.from(data);
    if (responseJson['updateAvailable'] != true) return null;

    final update = AppUpdate.fromFunctionResponse(responseJson);
    return update.isNewerThan(installedVersionCode) ? update : null;
  }

  @override
  Future<bool> downloadAndInstall(AppUpdate update) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('APK updates are available only on Android.');
    }
    if (!AppUpdate._isTrustedSignedDownloadUrl(
      update.downloadUrl,
      update.versionCode,
    )) {
      throw const FormatException('Update has an untrusted download URL.');
    }

    final updatesDirectory = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates',
    );
    await updatesDirectory.create(recursive: true);
    final apk = File(
      '${updatesDirectory.path}${Platform.pathSeparator}app-release.apk',
    );
    if (!await apk.exists() || await _fileSha256(apk) != update.sha256) {
      await _downloadVerifiedApk(
        Uri.parse(update.downloadUrl),
        apk,
        update.sha256,
      );
    }

    final canInstall =
        await channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;
    if (!canInstall) {
      await channel.invokeMethod<void>('requestInstallPermission');
      return false;
    }
    await channel.invokeMethod<void>('installApk', {'path': apk.path});
    return true;
  }

  Future<void> _downloadVerifiedApk(
    Uri uri,
    File destination,
    String expectedSha256,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'LoveAnniversaryApp');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'APK download failed (${response.statusCode}).',
          uri: uri,
        );
      }
      if (response.contentLength > _maximumApkBytes) {
        throw const FormatException('APK exceeds the supported download size.');
      }

      final digestSink = _DigestSink();
      final digestInput = sha256.startChunkedConversion(digestSink);
      final output = destination.openWrite();
      var outputClosed = false;
      var downloadedBytes = 0;
      try {
        await for (final chunk in response) {
          downloadedBytes += chunk.length;
          if (downloadedBytes > _maximumApkBytes) {
            throw const FormatException(
              'APK exceeds the supported download size.',
            );
          }
          digestInput.add(chunk);
          output.add(chunk);
        }
        digestInput.close();
        await output.flush();
        await output.close();
        outputClosed = true;
        if (digestSink.digest?.toString() != expectedSha256) {
          throw const FormatException(
            'Downloaded APK checksum does not match.',
          );
        }
      } catch (_) {
        if (!outputClosed) await output.close();
        if (await destination.exists()) await destination.delete();
        rethrow;
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _fileSha256(File file) async {
    final digestSink = _DigestSink();
    final digestInput = sha256.startChunkedConversion(digestSink);
    await for (final chunk in file.openRead()) {
      digestInput.add(chunk);
    }
    digestInput.close();
    return digestSink.digest?.toString() ??
        (throw StateError('Could not compute the APK checksum.'));
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest value) => digest = value;

  @override
  void close() {}
}
