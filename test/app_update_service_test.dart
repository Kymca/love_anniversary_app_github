import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/services/app_update_service.dart';

void main() {
  group('AppUpdate', () {
    const manifest = {
      'versionCode': 42,
      'sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'apkObjectPath': 'releases/42/app-release.apk',
      'versionName': '1.2.3',
      'packageName': appReleasePackageName,
      'releaseNotes': 'Bug fixes',
      'downloadUrl': 'https://xbbybirzhmhlsnvmyvxa.supabase.co/storage/v1/object/sign/app-releases/releases/42/app-release.apk?token=test-token',
    };

    test('parses the app-update-check response contract', () {
      final update = AppUpdate.fromFunctionResponse(manifest);

      expect(update.versionCode, 42);
      expect(update.versionName, '1.2.3');
      expect(update.apkObjectPath, 'releases/42/app-release.apk');
      expect(update.packageName, appReleasePackageName);
      expect(update.releaseNotes, 'Bug fixes');
      expect(update.isNewerThan(41), isTrue);
      expect(update.isNewerThan(42), isFalse);
    });

    test('rejects invalid manifest values and another package', () {
      expect(
        () => AppUpdate.fromFunctionResponse({...manifest, 'versionCode': 0}),
        throwsFormatException,
      );
      expect(
        () => AppUpdate.fromFunctionResponse({
          ...manifest,
          'apkObjectPath': 'releases/41/app-release.apk',
        }),
        throwsFormatException,
      );
      expect(
        () => AppUpdate.fromFunctionResponse({...manifest, 'sha256': 'wrong'}),
        throwsFormatException,
      );
      expect(
        () => AppUpdate.fromFunctionResponse({
          ...manifest,
          'packageName': 'attacker.app',
        }),
        throwsFormatException,
      );
    });

    test('accepts only a tokenized signed URL for this release asset', () {
      for (final downloadUrl in [
        'http://xbbybirzhmhlsnvmyvxa.supabase.co/storage/v1/object/sign/app-releases/releases/42/app-release.apk?token=x',
        'https://attacker.example/storage/v1/object/sign/app-releases/releases/42/app-release.apk?token=x',
        'https://xbbybirzhmhlsnvmyvxa.supabase.co/storage/v1/object/sign/app-releases/releases/41/app-release.apk?token=x',
        'https://xbbybirzhmhlsnvmyvxa.supabase.co/storage/v1/object/sign/other/releases/42/app-release.apk?token=x',
        'https://xbbybirzhmhlsnvmyvxa.supabase.co/storage/v1/object/sign/app-releases/releases/42/app-release.apk',
      ]) {
        expect(
          () => AppUpdate.fromFunctionResponse({
            ...manifest,
            'downloadUrl': downloadUrl,
          }),
          throwsFormatException,
        );
      }
    });
  });
}
