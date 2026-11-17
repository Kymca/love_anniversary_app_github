import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:love_anniversary_app/services/pair_email_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('new email sign-in verifies a code using the email OTP type', () async {
    final requests = <http.Request>[];
    final auth = GoTrueClient(
      url: 'https://example.supabase.co/auth/v1',
      headers: const {'apikey': 'test-key'},
      flowType: AuthFlowType.implicit,
      autoRefreshToken: false,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/verify')) {
          return httpResponse(
            _verifiedSession('new-user-id', 'person@example.com'),
          );
        }
        return httpResponse('{}');
      }),
    );
    final service = SupabasePairEmailAuthService(auth);

    await service.sendCode('Person@Example.com');
    await service.verifyCode('person@example.com', '654321');

    final otpRequest = requests.singleWhere(
      (request) => request.url.path.endsWith('/otp'),
    );
    expect(otpRequest.url.queryParameters, isEmpty);
    final verifyRequest = requests.singleWhere(
      (request) => request.url.path.endsWith('/verify'),
    );
    expect(jsonDecode(verifyRequest.body), {
      'email': 'person@example.com',
      'token': '654321',
      'type': 'email',
      'redirect_to': null,
      'gotrue_meta_security': {'captcha_token': null},
    });
    expect(service.isEmailVerified, isTrue);
  });

  test(
    'legacy anonymous user verifies email-change OTP without changing its id',
    () async {
      const userId = 'c7041bd4-28fb-4c75-9daa-3b4ff9ef48ac';
      final requests = <http.Request>[];
      final auth = GoTrueClient(
        url: 'https://example.supabase.co/auth/v1',
        headers: const {'apikey': 'test-key'},
        flowType: AuthFlowType.implicit,
        autoRefreshToken: false,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/token')) {
            return httpResponse(
              jsonEncode({
                'access_token': 'test-access-token',
                'token_type': 'bearer',
                'expires_in': 3600,
                'expires_at': 4070908800,
                'refresh_token': 'test-refresh-token',
                'user': _anonymousUser(userId),
              }),
            );
          }
          if (request.url.path.endsWith('/user')) {
            return httpResponse(
              jsonEncode({
                ..._anonymousUser(userId),
                'new_email': 'person@example.com',
                'updated_at': '2025-01-02T00:00:00.000Z',
              }),
            );
          }
          if (request.url.path.endsWith('/verify')) {
            return httpResponse(_verifiedSession(userId, 'person@example.com'));
          }
          return httpResponse('{}', statusCode: 404);
        }),
      );
      await auth.setSession('test-refresh-token');
      final service = SupabasePairEmailAuthService(auth);

      await service.sendCode('person@example.com');
      await service.verifyCode('person@example.com', '123456');

      final updateRequest = requests.singleWhere(
        (request) => request.url.path.endsWith('/user'),
      );
      expect(updateRequest.url.queryParameters, isEmpty);
      final verifyRequest = requests.singleWhere(
        (request) => request.url.path.endsWith('/verify'),
      );
      expect(jsonDecode(verifyRequest.body), {
        'email': 'person@example.com',
        'token': '123456',
        'type': 'email_change',
        'redirect_to': null,
        'gotrue_meta_security': {'captcha_token': null},
      });
      expect(auth.currentUser?.id, userId);
      expect(service.isEmailVerified, isTrue);
    },
  );

  test('send-code API errors are preserved for diagnosis', () async {
    final auth = GoTrueClient(
      url: 'https://example.supabase.co/auth/v1',
      headers: const {'apikey': 'test-key'},
      flowType: AuthFlowType.implicit,
      autoRefreshToken: false,
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/otp'));
        expect(request.url.queryParameters, isEmpty);
        return httpResponse(
          jsonEncode({
            'error_code': 'over_email_send_rate_limit',
            'msg': 'Email rate limit exceeded',
          }),
          statusCode: 429,
        );
      }),
    );

    await expectLater(
      SupabasePairEmailAuthService(auth).sendCode('person@example.com'),
      throwsA(
        isA<AuthApiException>()
            .having(
              (error) => error.message,
              'message',
              'Email rate limit exceeded',
            )
            .having((error) => error.statusCode, 'status code', '429')
            .having(
              (error) => error.code,
              'code',
              'over_email_send_rate_limit',
            ),
      ),
    );
  });
}

String _verifiedSession(String id, String email) => jsonEncode({
  'access_token': 'verified-access-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': 4070908800,
  'refresh_token': 'verified-refresh-token',
  'user': {
    'id': id,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': email,
    'email_confirmed_at': '2025-01-02T00:00:00.000Z',
    'app_metadata': {
      'provider': 'email',
      'providers': ['email'],
    },
    'user_metadata': <String, Object?>{},
    'created_at': '2025-01-01T00:00:00.000Z',
    'updated_at': '2025-01-02T00:00:00.000Z',
    'is_anonymous': false,
  },
});

Map<String, Object?> _anonymousUser(String id) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': null,
  'app_metadata': {
    'provider': 'anonymous',
    'providers': ['anonymous'],
  },
  'user_metadata': <String, Object?>{},
  'created_at': '2025-01-01T00:00:00.000Z',
  'updated_at': '2025-01-01T00:00:00.000Z',
  'is_anonymous': true,
};

http.Response httpResponse(String body, {int statusCode = 200}) =>
    http.Response(
      body,
      statusCode,
      headers: const {'content-type': 'application/json'},
    );
