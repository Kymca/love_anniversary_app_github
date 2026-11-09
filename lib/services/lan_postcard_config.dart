import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LanPostcardConfig {
  const LanPostcardConfig({
    required this.baseUrl,
    required this.token,
    required this.side,
  });

  static const storageKey = 'lan_postcard_config_v1';

  final String baseUrl;
  final String token;
  final String side;

  String get otherSide => side == 'first' ? 'second' : 'first';

  void validate() {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'Enter a base URL such as http://192.168.1.5:8787',
      );
    }
    if (token.length < 43 || token.length > 128) {
      throw const FormatException(
        'The access token must be at least 256 bits.',
      );
    }
    if (side != 'first' && side != 'second') {
      throw const FormatException('Choose a participant side.');
    }
  }

  Map<String, Object> toJson() => {
    'baseUrl': baseUrl.trim().replaceFirst(RegExp(r'/$'), ''),
    'token': token,
    'side': side,
  };

  static LanPostcardConfig fromJson(Map<String, dynamic> json) {
    final config = LanPostcardConfig(
      baseUrl: json['baseUrl'] as String,
      token: json['token'] as String,
      side: json['side'] as String,
    );
    config.validate();
    return config;
  }

  static Future<LanPostcardConfig?> load({
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return null;
    try {
      final object = jsonDecode(raw);
      if (object is! Map<String, dynamic>) {
        throw const FormatException('LAN postcard settings must be an object.');
      }
      return LanPostcardConfig.fromJson(object);
    } on FormatException {
      rethrow;
    } on TypeError {
      throw const FormatException('LAN postcard settings are malformed.');
    }
  }

  Future<void> save({SharedPreferences? preferences}) async {
    validate();
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final success = await prefs.setString(storageKey, jsonEncode(toJson()));
    if (!success) throw StateError('Could not save LAN postcard settings.');
  }
}
