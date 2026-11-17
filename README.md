# Love Anniversary

A Flutter app for a couple, with a duck companion, memories, wish coupons,
postcards, and small games.

## Wish coupons

The **Купоны на желания** tab stores coupons in a Hive box. Add or edit the
starter entries in `lib/services/coupon_repository.dart`; one-time coupons stay
spent, while monthly coupons become available again when the calendar month
changes.

Telegram notifications are optional. The app reads `TELEGRAM_BOT_TOKEN` and
`TELEGRAM_CHAT_ID` from Dart defines; without both, coupons still work locally
and the screen indicates that notifications are not configured. For example,
pass these defines through your private local build configuration rather than
committing their values. **A bot token embedded in a mobile app can be
extracted. For production, keep the token on a backend and inject a notifier
that calls your authenticated server endpoint instead.**

### Postcard LAN server

The **Открытки** tab keeps a local archive and can also send postcards through
the optional HTTP server in `tools/postcard_server.dart`. The server binds to
all IPv4 interfaces on the laptop, stores postcards in
`postcard_data/postcards.json`, validates requests, and requires a shared
256-bit bearer token scoped to the pair. It has no Firebase or FCM dependency;
the recipient checks for new postcards when the screen opens or when they tap
**Обновить входящие**.

On Windows, from the project root:

```powershell
dart run tools\postcard_server.dart
```

The server prints its Wi-Fi/LAN URL and a one-time generated token. Enter the
same URL and token on both phones under **Открытки → Настроить LAN-сервер**.
Select **Участник 1** on one phone and **Участник 2** on the other. The person
composing a card enters the partner's display name. To retain the same token
after a server restart, stop the server with Ctrl+C and start it in a PowerShell
session with the token copied from its first run:

```powershell
$env:POSTCARD_ACCESS_TOKEN = '<paste the generated token privately>'
dart run tools\postcard_server.dart
```

Use the printed phone URL (not `localhost`) and a trusted private Wi-Fi network.
Both phones and the laptop must be on that same network, the laptop must remain
on with the server running, and its firewall must allow inbound TCP port 8787
on the Private profile. If necessary, an administrator can explicitly allow it:

```powershell
New-NetFirewallRule -DisplayName "Love Anniversary postcard LAN" -Direction Inbound -Protocol TCP -LocalPort 8787 -Action Allow -Profile Private
```

The app stores the endpoint and bearer token in local preferences. Anyone who
obtains that token can access the pair's postcards, so only share it with the
partner and keep it out of source control and screenshots. This development
server uses plain HTTP: postcard contents and the bearer token are not encrypted
in transit. Use it only on a trusted private network, never public/guest Wi-Fi
or the Internet; do not forward the port from a router. No live push is sent,
and delivery is visible only after the recipient opens the app or manually
refreshes. This LAN option is not a production substitute for a TLS-protected,
authenticated hosted backend.

Android permits cleartext traffic for the user-configured local server, and iOS
declares local-network access. The local archive remains available if the
laptop server is offline; a send is added to the sent archive only after the
server confirms it has persisted the record.

### Duck notification sound and icon

When a coupon is activated, the app can also show a **local notification** on
the current device. It requests notification permission in response to that
user action. Android uses the `duck_coupons_v1` channel, the monochrome
`ic_notification_duck` status icon, and the short original `duck_ding.wav`
sound. Android keeps a channel's sound fixed after its first creation; users
can also mute or change it in system notification settings.

iOS uses the bundled `duck_ding.wav` sound and the existing duck sprite as an
expanded notification attachment. iOS does not allow an app to replace the
notification's system app icon with an arbitrary duck avatar; the app icon
remains system-controlled.

This is local notification support only. No FCM/APNs provider or server-side
push backend is configured. Remote push requires a separately configured
provider; each OS and user notification settings can still override sound and
display.

### Daily moods together and movie night

The **Настроение вдвоём** and **Кино-ночь** cards are a same-device demo backed
by `SharedPreferences`. Both daily mood selections are stored locally and
produce a duck reaction (a cozy blanket/tea for two blue moods, a dance for two
joyful moods, otherwise a supportive prompt). Movie night starts with five
random unique unwatched suggestions; users can add titles, mark them watched,
and record two locally hidden votes. A shared like shows a match, duck image,
and local chime notification.

The votes are not private from someone with access to the shared device, and
neither moods nor votes sync to a partner's phone. True paired identity,
private cross-device ballots, remote match alerts and reliable server push all
require an authenticated backend/provider; none is configured in this build.

The cinema search can use TMDB's paginated movie catalog. For a local
development build, provide a TMDB API key with
`--dart-define=TMDB_API_KEY=your_key`; if it is omitted, the search uses a small
offline suggestion catalog and users can still add arbitrary titles manually.
TMDB is a large third-party catalog, not a guarantee of every film ever made.
Do not ship a personal TMDB key in a production mobile app: mobile build
defines are extractable. Production should call TMDB through a backend proxy
that keeps credentials server-side.

TMDB attribution: “This product uses the TMDB API but is not endorsed or
certified by TMDB.” If TMDB artwork or logos are displayed in a future UI,
follow TMDB's current logo, attribution, and brand usage requirements as well.

## Getting started

Install the Flutter SDK (Dart `^3.13.7`), then run these commands from the
project root:

```shell
flutter pub get
flutter run
```

Run the test suite with `flutter test` and static analysis with
`flutter analyze`. Generated localization sources are committed under
`lib/l10n/generated`; edit the ARB files in `lib/l10n/` and regenerate them
with `flutter gen-l10n`.

### Android APK builds and in-app updates

`.github/workflows/android-release.yml` builds a signed Android APK on pushes
to `main` and on manual workflow dispatch targeting `main`. It uploads the APK
and manifests only to the private Supabase Storage bucket
`app-releases`; it
does not upload APKs to GitHub Releases or Actions artifacts. The bucket must
already exist and remain private. The workflow verifies the bucket's privacy
before uploading. It writes immutable versioned objects
`releases/<versionCode>/app-release.apk` and
`releases/<versionCode>/manifest.json`, then updates
`releases/latest.json`.
The manifest contains `versionCode`, `sha256`, `apkObjectPath`, `versionName`,
`packageName`, and `releaseNotes`.

The owner has applied the private-bucket migration and deployed
`app-update-check` v1. The bucket remains empty until a signed release workflow
run uploads an APK and manifest. In GitHub **Settings → Secrets and variables
→ Actions**, add repository
secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`,
`ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`,
and `SUPABASE_SECRET_KEY` (the Supabase secret API key, prefixed `sb_secret_`).
The workflow sends it only in the Storage `apikey` header; it does not use a
Bearer authorization header. Do not substitute the publishable key. `SUPABASE_URL`
is the public project URL and is fixed in the workflow, so it is not a secret.
The Edge Function continues using Supabase's server-side
`SUPABASE_SERVICE_ROLE_KEY` environment internally; do not add that value to
GitHub Actions secrets, Dart defines, the app, or source control. The currently
installed APK's signing certificate was
confirmed to match the local Android debug keystore at
`%USERPROFILE%\.android\debug.keystore`; use that exact keystore for
`ANDROID_KEYSTORE_BASE64`, with its matching alias/passwords in the other
Android secrets. Keep it private and backed up. This is a debug
keystore, not a dedicated production key; changing signing keys later prevents
in-place updates without reinstalling the app.

The app calls the `app-update-check` Edge Function with its installed
`versionCode` and package name. The function reads the private
`releases/latest.json`, compares package/version, creates a five-minute signed
URL for exactly the manifest's `apkObjectPath`, and returns `updateAvailable`
plus the manifest fields and `downloadUrl`. The mobile app uses only the
existing Supabase publishable key; it has no service-role credential. Function
source, `verify_jwt = false` configuration, and private-bucket migration are
included in this repository. The deployed v1 function was checked against the
same bucket, manifest path, and response contract. The bucket is currently
empty; this work has not uploaded an APK or manifest.

Because this app has no user sign-in, `app-update-check` must be callable
anonymously (for example with Edge Function JWT verification disabled). Keep
the endpoint read-only: return update metadata and a short-lived signed URL
for this one bucket/object only. Keep the bucket private and the service-role
credential server-side; never expose it to the app.

The current app's selected Dart sources and required app assets have been
synced into this branch. Private `result.json`, machine-local configuration,
and build/cache artifacts were not copied; the GitHub-only LAN postcard
modules were preserved.

The current pair, shared-mood, shared-coupon, and push client code may need
newer Supabase backend objects than production currently has. Those pair/push
migrations and Edge Functions are intentionally outside this updater change
and were not applied or deployed. Before releasing the synchronized app,
review the backend requirements separately, including migrations
`20261114170000_allow_anonymous_pair_members`,
`20261115100000_pair_shared_moods_and_membership_guards`,
`20261117100000_pair_shared_coupons`, and
`20261117130000_pair_push_notifications`, plus the
`register-push-device` and `push-dispatch` functions. Existing production
pairing migrations are older equivalents and should not be blindly reapplied.
The optional pair-push registration also requires Firebase client Dart defines;
without them, push registration remains disabled.

To integrate this updater into another app checkout, merge the updater service,
function/config/migration and test, then make a surgical merge in that checkout's `lib/main.dart` to
import and initialize `SupabaseAppUpdateService` and retain its update UI; do
not replace the whole file. Also merge the Android package-install permission,
FileProvider/cache path, and `MainActivity` method-channel handlers from this
branch. Keep the existing app's package ID and Supabase project aligned with
the release manifest/function.

Android `versionCode` is `1000 + GITHUB_RUN_NUMBER`, so the first CI release
is greater than the checked-in `pubspec.yaml` build number `1` and subsequent
workflow runs remain monotonic. `versionName` comes from `pubspec.yaml`.
The current package name is
`com.example.love_anniversary_app`. The key and package name must match the
installed APK. Android still requires the user to allow installs from this app
and confirm installation in the system installer. This updater is separate
from push notifications.

## Local configuration and private data

Optional API values are supplied at build time with Dart defines. For local
development, set them in your shell or a private, untracked launch
configuration; never commit their values. For example, on PowerShell:

```powershell
flutter run `
  --dart-define="TMDB_API_KEY=$env:TMDB_API_KEY" `
  --dart-define="TELEGRAM_BOT_TOKEN=$env:TELEGRAM_BOT_TOKEN" `
  --dart-define="TELEGRAM_CHAT_ID=$env:TELEGRAM_CHAT_ID"
```

The app remains usable without these optional values. Dart defines are
embedded in mobile builds and can be extracted, so production credentials
belong on a backend, not in the app.

The Telegram chat export `result.json` is private user data and is deliberately
excluded from version control and the Flutter asset bundle. The random-memory
card requires a personal export; to enable it for a local build, restore your
own `result.json` and locally add `- result.json` under `flutter.assets` in
`pubspec.yaml`, then run `flutter pub get`. Do not commit the export or that
local manifest change. Removing the export does not delete it from your
computer.

No license is currently included. Choose and add a license before publishing
if you want to grant others permission to reuse the project.
