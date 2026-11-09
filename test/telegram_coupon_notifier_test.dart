import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:love_anniversary_app/models/coupon.dart';
import 'package:love_anniversary_app/services/telegram_coupon_notifier.dart';

void main() {
  const coupon = Coupon(
    id: 'test',
    title: 'Массаж_на 100%!',
    description: 'Подарок (для тебя).',
    icon: 'spa',
    type: CouponType.oneTime,
  );

  test('sends MarkdownV2 message to injected Telegram endpoint', () async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response('{"ok":true}', 200);
    });
    final notifier = TelegramCouponNotifier(
      endpoint: Uri.parse('https://api.example.test/sendMessage'),
      chatId: '12345',
      client: client,
    );

    await notifier.notifyActivated(coupon);

    expect(request.method, 'POST');
    expect(request.url.path, '/sendMessage');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['chat_id'], '12345');
    expect(body['parse_mode'], 'MarkdownV2');
    expect(body['text'], contains(r'Массаж\_на 100%\!'));
    expect(body['text'], contains(r'\(для тебя\)\.'));
    client.close();
  });

  test(
    'surfaces Telegram API errors without exposing endpoint credentials',
    () {
      final notifier = TelegramCouponNotifier(
        token: 'test-secret-token',
        chatId: '12345',
        client: MockClient(
          (_) async =>
              http.Response('{"ok":false,"description":"denied"}', 200),
        ),
      );

      expect(
        notifier.notifyActivated(coupon),
        throwsA(
          isA<TelegramNotificationException>().having(
            (error) => error.message,
            'message',
            'Telegram отклонил уведомление.',
          ),
        ),
      );
    },
  );

  test('surfaces non-success HTTP responses', () async {
    final notifier = TelegramCouponNotifier(
      endpoint: Uri.parse('https://api.example.test/sendMessage'),
      chatId: '12345',
      client: MockClient((_) async => http.Response('', 503)),
    );

    await expectLater(
      notifier.notifyActivated(coupon),
      throwsA(isA<TelegramNotificationException>()),
    );
  });
}
