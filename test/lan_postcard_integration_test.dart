import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/postcard.dart';
import 'package:love_anniversary_app/services/lan_postcard_config.dart';
import 'package:love_anniversary_app/services/lan_postcard_gateway.dart';
import 'package:love_anniversary_app/services/lan_postcard_server.dart';
import 'package:http/http.dart' as http;

void main() {
  const token = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFG';
  late Directory directory;
  late File store;
  late LanPostcardServer server;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lan-postcard-test-');
    store = File('${directory.path}${Platform.pathSeparator}cards.json');
    server = await LanPostcardServer.bind(
      address: InternetAddress.loopbackIPv4,
      port: 0,
      token: token,
      dataFile: store,
    );
  });

  tearDown(() async {
    await server.close();
    await directory.delete(recursive: true);
  });

  LanPostcardGateway gateway(String side, {String accessToken = token}) =>
      LanPostcardGateway(
        config: LanPostcardConfig(
          baseUrl: 'http://127.0.0.1:${server.port}',
          token: accessToken,
          side: side,
        ),
        senderName: side == 'first' ? 'Alex' : 'Sam',
      );

  test(
    'sender persists a postcard and only the paired recipient receives it',
    () async {
      final sender = gateway('first');
      final receiver = gateway('second');
      final sent = await sender.sendPostcard(
        recipientId: 'Sam',
        message: 'A real LAN delivery',
      );

      expect(sent.direction, PostcardDirection.sent);
      expect(sent.peerName, 'Sam');
      expect(await sender.loadReceivedPostcards(), isEmpty);

      final incoming = await receiver.loadReceivedPostcards();
      expect(incoming, hasLength(1));
      expect(incoming.single.id, sent.id);
      expect(incoming.single.message, 'A real LAN delivery');
      expect(incoming.single.peerName, 'Alex');
      expect((await receiver.loadReceivedPostcard(sent.id))?.id, sent.id);
    },
  );

  test('records remain available after server restart', () async {
    final sent = await gateway('first')
        .sendPostcard(recipientId: 'Sam', message: 'Persisted on disk');
    await server.close();
    server = await LanPostcardServer.bind(
      address: InternetAddress.loopbackIPv4,
      port: 0,
      token: token,
      dataFile: store,
    );

    final restored = await gateway('second').loadReceivedPostcards();
    expect(restored.single.id, sent.id);
    expect(restored.single.message, 'Persisted on disk');
  });

  test(
    'server rejects missing or invalid room credentials and schema',
    () async {
      final uri = Uri.parse('http://127.0.0.1:${server.port}/v1/postcards');
      final missingAuth = await http.get(uri);
      expect(missingAuth.statusCode, HttpStatus.unauthorized);

      final invalidSide = await http.post(
        uri,
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $token',
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: '{"senderSide":"admin","recipientSide":"second"}',
      );
      expect(invalidSide.statusCode, HttpStatus.badRequest);
    },
  );

  test('server caps request size and validates cross-side delivery', () async {
    final uri = Uri.parse('http://127.0.0.1:${server.port}/v1/postcards');
    final headers = {
      HttpHeaders.authorizationHeader: 'Bearer $token',
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    final tooLarge = await http.post(
      uri,
      headers: headers,
      body: '{"message":"${'x' * 9000}"}',
    );
    expect(tooLarge.statusCode, HttpStatus.requestEntityTooLarge);

    final sameSide = await http.post(
      uri,
      headers: headers,
      body:
          '{"senderSide":"first","recipientSide":"first","senderName":"Alex",'
          '"recipientName":"Alex","message":"no"}',
    );
    expect(sameSide.statusCode, HttpStatus.badRequest);
  });
}
