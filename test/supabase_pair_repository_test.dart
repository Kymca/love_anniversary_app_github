import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:love_anniversary_app/services/supabase_pair_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final isAnonymous in [true, false]) {
    for (final operation in ['create', 'join']) {
      test(
        '${isAnonymous ? 'anonymous' : 'email-confirmed'} user can $operation pair',
        () async {
          SharedPreferences.setMockInitialValues({});
          final preferences = await SharedPreferences.getInstance();
          final requests = <http.Request>[];
          final client = SupabaseClient(
            'https://example.supabase.co',
            'test-publishable-key',
            httpClient: MockClient((request) async {
              requests.add(request);
              if (request.url.path.endsWith('/auth/v1/user')) {
                return _jsonResponse(request, _userJson(isAnonymous: false));
              }
              if (request.url.path.endsWith('/auth/v1/signup')) {
                return _jsonResponse(request, {
                  'access_token': _accessToken(isAnonymous: true),
                  'token_type': 'bearer',
                  'expires_in': 3600,
                  'refresh_token': 'anonymous-refresh-token',
                  'user': _userJson(isAnonymous: true),
                });
              }
              if (request.url.path.endsWith('/rest/v1/rpc/create_pair') ||
                  request.url.path.endsWith('/rest/v1/rpc/join_pair')) {
                return _jsonResponse(request, {
                  'id': '00000000-0000-4000-8000-000000000001',
                  'code': '1234',
                  'firstName': 'Алина',
                  'secondName': operation == 'join' ? 'Саша' : null,
                });
              }
              return http.Response('Unexpected request', 500);
            }),
          );
          try {
            if (!isAnonymous) {
              await client.auth.setSession(
                'email-confirmed-refresh-token',
                accessToken: _accessToken(isAnonymous: false),
              );
            }
            final repository = SupabasePairRepository(
              client,
              preferences: preferences,
            );

            final room = operation == 'create'
                ? await repository.createPair('Алина')
                : await repository.joinPair('Саша', '1234');

            expect(room.code, '1234');
            expect(client.auth.currentUser?.isAnonymous, isAnonymous);
            expect(
              requests.where(
                (request) => request.url.path.endsWith('/auth/v1/signup'),
              ),
              hasLength(isAnonymous ? 1 : 0),
            );
            expect(
              requests.where(
                (request) => request.url.path.endsWith(
                  '/rest/v1/rpc/${operation == 'create' ? 'create_pair' : 'join_pair'}',
                ),
              ),
              hasLength(1),
            );
          } finally {
            await client.dispose();
          }
        },
      );
    }
  }
}

http.Response _jsonResponse(http.Request request, Map<String, Object?> body) =>
    http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );

Map<String, Object?> _userJson({required bool isAnonymous}) => {
  'id': '00000000-0000-4000-8000-000000000002',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': isAnonymous ? null : 'user@example.com',
  'app_metadata': {
    'provider': isAnonymous ? 'anonymous' : 'email',
    'providers': [if (!isAnonymous) 'email'],
  },
  'user_metadata': <String, Object?>{},
  'created_at': '2026-01-01T00:00:00Z',
  'email_confirmed_at': isAnonymous ? null : '2026-01-01T00:00:00Z',
  'is_anonymous': isAnonymous,
};

String _accessToken({required bool isAnonymous}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  String encode(Map<String, Object?> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none', 'typ': 'JWT'})}.'
      '${encode({'sub': '00000000-0000-4000-8000-000000000002', 'aud': 'authenticated', 'role': 'authenticated', 'iat': now, 'exp': now + 3600, 'is_anonymous': isAnonymous})}.${base64Url.encode([1, 2, 3]).replaceAll('=', '')}';
}
