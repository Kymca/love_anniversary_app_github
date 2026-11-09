import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appLocalePreferenceKey = 'app_locale';
const appSupportedLocales = [Locale('ru'), Locale('uk')];

Locale appLocaleFromLanguageCode(String? languageCode) =>
    appSupportedLocales.firstWhere(
      (locale) => locale.languageCode == languageCode,
      orElse: () => appSupportedLocales.first,
    );

Future<Locale> loadSavedAppLocale() async {
  final preferences = await SharedPreferences.getInstance();
  return appLocaleFromLanguageCode(
    preferences.getString(appLocalePreferenceKey),
  );
}

Future<void> saveAppLocale(Locale locale) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(appLocalePreferenceKey, locale.languageCode);
}
