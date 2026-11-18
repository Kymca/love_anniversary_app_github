class AppRelease {
  const AppRelease({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.abi,
    required this.sha256,
    required this.apkObjectPath,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  static const expectedPackageName = 'com.example.love_anniversary_app';
  static const _maximumReleaseNotesLength = 8000;
  static const supportedAbis = {'arm64-v8a', 'armeabi-v7a', 'x86_64'};

  final String packageName;
  final String versionName;
  final int versionCode;
  final String abi;
  final String sha256;
  final String apkObjectPath;
  final Uri downloadUrl;
  final String releaseNotes;

  bool isNewerThan(int installedVersionCode) =>
      versionCode > installedVersionCode;

  bool hasTrustedDownloadLocation(Uri supabaseBaseUrl) =>
      supabaseBaseUrl.scheme == 'https' &&
      downloadUrl.scheme == 'https' &&
      downloadUrl.host == supabaseBaseUrl.host &&
      downloadUrl.port == supabaseBaseUrl.port &&
      downloadUrl.userInfo.isEmpty &&
      downloadUrl.fragment.isEmpty &&
      downloadUrl.path ==
          '/storage/v1/object/sign/app-releases/$apkObjectPath' &&
      downloadUrl.queryParameters['token']?.isNotEmpty == true;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final packageName = json['packageName'];
    final versionName = json['versionName'];
    final versionCode = json['versionCode'];
    final abi = json['abi'];
    final sha256 = json['sha256'];
    final apkObjectPath = json['apkObjectPath'];
    final downloadUrl = json['downloadUrl'];
    final releaseNotes = json['releaseNotes'];

    if (packageName != expectedPackageName ||
        versionName is! String ||
        versionName.isEmpty ||
        versionName.length > 64 ||
        versionCode is! int ||
        versionCode < 1 ||
        abi is! String ||
        !supportedAbis.contains(abi) ||
        sha256 is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256) ||
        apkObjectPath != 'releases/$versionCode/app-$abi.apk' ||
        downloadUrl is! String ||
        releaseNotes is! String ||
        releaseNotes.length > _maximumReleaseNotesLength) {
      throw const FormatException('Invalid app release manifest.');
    }

    final uri = Uri.tryParse(downloadUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.queryParameters['token']?.isNotEmpty != true) {
      throw const FormatException('Invalid signed APK URL.');
    }

    return AppRelease(
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      abi: abi,
      sha256: sha256.toLowerCase(),
      apkObjectPath: apkObjectPath as String,
      downloadUrl: uri,
      releaseNotes: releaseNotes,
    );
  }

  static AppRelease? fromUpdateResponse(
    Map<String, dynamic> json, {
    required Uri supabaseBaseUrl,
    required int installedVersionCode,
  }) {
    final updateAvailable = json['updateAvailable'];
    if (updateAvailable is! bool) {
      throw const FormatException('Invalid app update response.');
    }
    if (!updateAvailable) return null;

    final release = AppRelease.fromJson(json);
    if (!release.isNewerThan(installedVersionCode)) {
      throw const FormatException('Update response is not newer than the app.');
    }
    if (!release.hasTrustedDownloadLocation(supabaseBaseUrl)) {
      throw const FormatException('APK URL is outside the release storage.');
    }
    return release;
  }
}
