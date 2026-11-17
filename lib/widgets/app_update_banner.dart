import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/app_release.dart';

class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({
    required this.release,
    required this.isInstalling,
    required this.onInstall,
    required this.onDismiss,
    super.key,
  });

  final AppRelease release;
  final bool isInstalling;
  final VoidCallback onInstall;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return MaterialBanner(
      leading: const Icon(Icons.system_update_alt_rounded),
      content: Text(
        '${strings.appUpdateMessage} ${release.versionName}'
        '${release.releaseNotes.isEmpty ? '' : '\n${release.releaseNotes}'}',
      ),
      actions: [
        TextButton(
          onPressed: isInstalling ? null : onInstall,
          child: Text(
            isInstalling
                ? strings.appUpdateInstalling
                : strings.appUpdateAction,
          ),
        ),
        TextButton(
          onPressed: isInstalling ? null : onDismiss,
          child: Text(strings.appUpdateDismiss),
        ),
      ],
    );
  }
}
