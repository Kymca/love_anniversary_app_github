import 'package:http/http.dart' as http;

import '../models/coupon.dart';
import 'telegram_bot_api.dart';

export 'telegram_bot_api.dart' show TelegramNotificationException;

abstract interface class CouponActivationNotifier {
  Future<void> notifyActivated(Coupon coupon);
}

class TelegramCouponNotifier implements CouponActivationNotifier {
  TelegramCouponNotifier({
    String? token,
    required String chatId,
    Uri? endpoint,
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  }) : api = TelegramBotApi(
         token: token,
         chatId: chatId,
         endpoint: endpoint,
         client: client,
         timeout: timeout,
       );

  TelegramCouponNotifier.withApi(this.api);

  final TelegramBotApi api;

  @override
  Future<void> notifyActivated(Coupon coupon) async {
    final text = [
      '*Купон активирован*',
      '',
      '*${_escapeMarkdownV2(coupon.title)}*',
      if (coupon.description.trim().isNotEmpty)
        _escapeMarkdownV2(coupon.description),
    ].join('\n');

    await api.sendMessage(text, parseMode: 'MarkdownV2');
  }

  static String _escapeMarkdownV2(String value) {
    return value.replaceAllMapped(
      RegExp(r'([_*\[\]()~`>#+\-=|{}.!\\])'),
      (match) => '\\${match[0]}',
    );
  }
}
