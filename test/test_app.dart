import 'package:flutter/material.dart';
import 'package:love_anniversary_app/l10n/generated/app_localizations.dart';

Widget localizedTestApp({
  required Widget home,
  Locale locale = const Locale('ru'),
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
