import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/l10n/generated/app_localizations.dart';
import 'package:love_anniversary_app/main.dart';
import 'package:love_anniversary_app/models/app_release.dart';
import 'package:love_anniversary_app/screens/settings_screen.dart';
import 'package:love_anniversary_app/services/app_update_service.dart';
import 'package:love_anniversary_app/widgets/app_update_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final releaseJson = <String, dynamic>{
    'packageName': AppRelease.expectedPackageName,
    'versionName': '1.0.1',
    'versionCode': 2,
    'abi': 'arm64-v8a',
    'sha256': List.filled(64, 'a').join(),
    'apkObjectPath': 'releases/2/app-arm64-v8a.apk',
    'downloadUrl': 'https://xbbybirzhmhlsnvmyvxa.supabase.co/storage/v1/object/sign/app-releases/releases/2/app-arm64-v8a.apk?token=test',
    'releaseNotes': 'Improvements',
  };

  test(
    'parses a release and compares monotonically increasing version codes',
    () {
      final release = AppRelease.fromJson(releaseJson);

      expect(release.versionCode, 2);
      expect(release.abi, 'arm64-v8a');
      expect(release.isNewerThan(1), isTrue);
      expect(release.isNewerThan(2), isFalse);
      expect(release.isNewerThan(3), isFalse);
      expect(
        release.hasTrustedDownloadLocation(
          Uri.parse('https://xbbybirzhmhlsnvmyvxa.supabase.co'),
        ),
        isTrue,
      );
      expect(
        release.hasTrustedDownloadLocation(
          Uri.parse('https://attacker.example'),
        ),
        isFalse,
      );
    },
  );

  test('accepts split APK variants for every supported Android ABI', () {
    for (final abi in AppRelease.supportedAbis) {
      final apkObjectPath = 'releases/2/app-$abi.apk';
      final release = AppRelease.fromJson({
        ...releaseJson,
        'abi': abi,
        'apkObjectPath': apkObjectPath,
        'downloadUrl':
            'https://xbbybirzhmhlsnvmyvxa.supabase.co/storage/v1/object/sign/app-releases/$apkObjectPath?token=test',
      });

      expect(release.abi, abi);
      expect(release.apkObjectPath, apkObjectPath);
      expect(
        release.hasTrustedDownloadLocation(
          Uri.parse('https://xbbybirzhmhlsnvmyvxa.supabase.co'),
        ),
        isTrue,
      );
    }
  });

  test('parses update-check responses and validates the server decision', () {
    final baseUrl = Uri.parse('https://xbbybirzhmhlsnvmyvxa.supabase.co');

    expect(
      AppRelease.fromUpdateResponse(
        {'updateAvailable': false},
        supabaseBaseUrl: baseUrl,
        installedVersionCode: 1,
      ),
      isNull,
    );
    expect(
      AppRelease.fromUpdateResponse(
        {'updateAvailable': true, ...releaseJson},
        supabaseBaseUrl: baseUrl,
        installedVersionCode: 1,
      )?.versionCode,
      2,
    );
    expect(
      () => AppRelease.fromUpdateResponse(
        releaseJson,
        supabaseBaseUrl: baseUrl,
        installedVersionCode: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => AppRelease.fromUpdateResponse(
        {'updateAvailable': true, ...releaseJson},
        supabaseBaseUrl: baseUrl,
        installedVersionCode: 2,
      ),
      throwsFormatException,
    );
  });

  test('rejects non-HTTPS, malformed, or unexpected app releases', () {
    expect(
      () => AppRelease.fromJson({
        ...releaseJson,
        'downloadUrl': 'http://xbbybirzhmhlsnvmyvxa.supabase.co/storage/v1/object/sign/app-releases/releases/2/app-arm64-v8a.apk?token=test',
      }),
      throwsFormatException,
    );
    expect(
      () => AppRelease.fromJson({...releaseJson, 'packageName': 'other.app'}),
      throwsFormatException,
    );
    expect(
      () => AppRelease.fromJson({...releaseJson, 'sha256': 'invalid'}),
      throwsFormatException,
    );
    expect(
      () => AppRelease.fromJson({
        ...releaseJson,
        'apkObjectPath': 'releases/3/app-arm64-v8a.apk',
      }),
      throwsFormatException,
    );
    expect(
      () => AppRelease.fromJson({...releaseJson, 'abi': 'riscv64'}),
      throwsFormatException,
    );
    expect(
      () => AppRelease.fromUpdateResponse(
        {
          'updateAvailable': true,
          ...releaseJson,
          'downloadUrl': 'https://xbbybirzhmhlsnvmyvxa.supabase.co/storage/v1/object/sign/another-bucket/releases/2/app-arm64-v8a.apk?token=test',
        },
        supabaseBaseUrl: Uri.parse('https://xbbybirzhmhlsnvmyvxa.supabase.co'),
        installedVersionCode: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => AppRelease.fromJson({
        ...releaseJson,
        'downloadUrl': 'https://xbbybirzhmhlsnvmyvxa.supabase.co/storage/v1/object/sign/app-releases/releases/2/app-arm64-v8a.apk',
      }),
      throwsFormatException,
    );
  });

  testWidgets('shows an update action and invokes it when tapped', (
    tester,
  ) async {
    var installs = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AppUpdateBanner(
            release: AppRelease.fromJson(releaseJson),
            isInstalling: false,
            onInstall: () => installs++,
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Доступно обновление'), findsOneWidget);
    await tester.tap(find.text('Обновить'));
    expect(installs, 1);
  });

  testWidgets('checks for an update when the app opens', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final release = AppRelease.fromJson(releaseJson);
    await tester.pumpWidget(
      LoveAnniversaryApp(appUpdateService: _FakeAppUpdateService(release)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Доступно обновление'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings manually checks and reports update results', (
    tester,
  ) async {
    final pendingCheck = Completer<AppRelease?>();
    Future<AppRelease?> Function() checkForUpdate = () => pendingCheck.future;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          authService: null,
          onCheckForUpdate: () => checkForUpdate(),
        ),
      ),
    );

    await tester.tap(find.text('Проверить обновления'));
    await tester.pump();
    expect(find.text('Проверяем обновления…'), findsOneWidget);

    pendingCheck.complete(AppRelease.fromJson(releaseJson));
    await tester.pumpAndSettle();
    expect(find.text('Доступно обновление 1.0.1'), findsOneWidget);

    checkForUpdate = () async => null;
    await tester.tap(find.text('Проверить обновления'));
    await tester.pumpAndSettle();
    expect(find.text('У вас установлена последняя версия.'), findsOneWidget);

    checkForUpdate = () async => throw StateError('check failed');
    await tester.tap(find.text('Проверить обновления'));
    await tester.pumpAndSettle();
    expect(
      find.text('Не удалось проверить обновления. Попробуйте позже.'),
      findsOneWidget,
    );
  });
}

class _FakeAppUpdateService implements AppUpdateService {
  _FakeAppUpdateService(this.release);

  final AppRelease release;

  @override
  Future<AppRelease?> checkForUpdate() async => release;

  @override
  Future<void> installUpdate(AppRelease update) async {}
}
