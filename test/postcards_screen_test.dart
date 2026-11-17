import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/postcard.dart';
import 'package:love_anniversary_app/screens/postcards_screen.dart';
import 'package:love_anniversary_app/services/postcard_delivery_gateway.dart';
import 'package:love_anniversary_app/services/postcard_push_gateway.dart';
import 'package:love_anniversary_app/services/postcard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('archive persists sent and received postcards across reloads', () async {
    final repository = PostcardRepository();
    await repository.recordSent(
      Postcard(
        id: 'sent-1',
        message: 'A little hello',
        createdAt: DateTime(2026, 11, 6, 10),
        direction: PostcardDirection.sent,
        peerName: 'Partner',
      ),
    );
    await repository.recordReceived(
      Postcard(
        id: 'received-1',
        message: 'Thinking of you',
        createdAt: DateTime(2026, 11, 6, 11),
        direction: PostcardDirection.received,
        peerName: 'Partner',
      ),
    );

    final restored = await PostcardRepository().load();
    expect(restored.map((card) => card.id), ['received-1', 'sent-1']);
    expect(restored.first.direction, PostcardDirection.received);
    expect(restored.last.direction, PostcardDirection.sent);
  });

  testWidgets('archive filters sent and received postcards separately', (
    tester,
  ) async {
    final repository = PostcardRepository();
    await repository.recordSent(
      Postcard(
        id: 'sent-1',
        message: 'Sent note',
        createdAt: DateTime(2026, 11, 6),
        direction: PostcardDirection.sent,
        peerName: 'Partner',
      ),
    );
    await repository.recordReceived(
      Postcard(
        id: 'received-1',
        message: 'Received note',
        createdAt: DateTime(2026, 11, 6, 1),
        direction: PostcardDirection.received,
        peerName: 'Partner',
      ),
    );
    await tester.pumpWidget(
      localizedTestApp(home: PostcardsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sent note'), findsOneWidget);
    expect(find.text('Received note'), findsOneWidget);
    expect(
      find.textContaining(
        'Синхронизация открыток с сервером пока не подключена.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Отправленные'));
    await tester.pumpAndSettle();
    expect(find.text('Sent note'), findsOneWidget);
    expect(find.text('Received note'), findsNothing);
    await tester.tap(find.text('Полученные'));
    await tester.pumpAndSettle();
    expect(find.text('Received note'), findsOneWidget);
    expect(find.text('Sent note'), findsNothing);
  });

  testWidgets('only a gateway-confirmed send enters sent archive', (
    tester,
  ) async {
    final repository = PostcardRepository();
    final deliveryGateway = _FakePostcardDeliveryGateway();
    final pushGateway = _FakePostcardPushGateway();
    await tester.pumpWidget(
      localizedTestApp(
        home: PostcardsScreen(
          repository: repository,
          deliveryGateway: deliveryGateway,
          pushGateway: pushGateway,
        ),
      ),
    );
    addTearDown(pushGateway.dispose);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compose-postcard')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'recipient-123');
    await tester.enterText(find.byType(TextField).at(1), 'Hello from us');
    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle();

    expect(deliveryGateway.sentRecipientIds, ['recipient-123']);
    expect((await repository.load()).single.direction, PostcardDirection.sent);
    expect((await repository.load()).single.message, 'Hello from us');
  });

  testWidgets('unconfigured push cannot report a sent postcard', (
    tester,
  ) async {
    final repository = PostcardRepository();
    await tester.pumpWidget(
      localizedTestApp(home: PostcardsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compose-postcard')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'recipient-123');
    await tester.enterText(find.byType(TextField).at(1), 'Hello from us');
    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Синхронизация открыток с сервером пока не подключена.',
      ),
      findsWidgets,
    );
    expect(await repository.load(), isEmpty);
  });

  testWidgets('received push is persisted to the received archive', (
    tester,
  ) async {
    final repository = PostcardRepository();
    final deliveryGateway = _FakePostcardDeliveryGateway();
    final pushGateway = _FakePostcardPushGateway();
    await tester.pumpWidget(
      localizedTestApp(
        home: PostcardsScreen(
          repository: repository,
          deliveryGateway: deliveryGateway,
          pushGateway: pushGateway,
        ),
      ),
    );
    addTearDown(pushGateway.dispose);
    await tester.pumpAndSettle();
    final incomingPostcard = Postcard(
      id: 'incoming-1',
      message: 'A received card',
      createdAt: DateTime(2026, 11, 6),
      direction: PostcardDirection.received,
      peerName: 'My partner',
    );
    deliveryGateway.storeReceived(incomingPostcard);
    pushGateway.signal(incomingPostcard.id);
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(deliveryGateway.loadedPostcardIds, ['incoming-1']);
    expect((await repository.load()).single.id, 'incoming-1');
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('A received card'), findsOneWidget);
    expect(
      (await repository.load()).single.direction,
      PostcardDirection.received,
    );
  });

  testWidgets('push ID is not archived without fetching backend data', (
    tester,
  ) async {
    final repository = PostcardRepository();
    final pushGateway = _FakePostcardPushGateway();
    await tester.pumpWidget(
      localizedTestApp(
        home: PostcardsScreen(repository: repository, pushGateway: pushGateway),
      ),
    );
    addTearDown(pushGateway.dispose);
    await tester.pumpAndSettle();
    pushGateway.signal('not-yet-fetched');
    await tester.pumpAndSettle();

    expect(await repository.load(), isEmpty);
    expect(
      find.textContaining(
        'Синхронизация открыток с сервером пока не подключена.',
      ),
      findsOneWidget,
    );
  });
}

class _FakePostcardPushGateway implements PostcardPushGateway {
  final _receivedIds = StreamController<String>.broadcast();

  @override
  Stream<String> get receivedPostcardIds => _receivedIds.stream;

  void signal(String postcardId) => _receivedIds.add(postcardId);

  Future<void> dispose() => _receivedIds.close();
}

class _FakePostcardDeliveryGateway implements PostcardDeliveryGateway {
  final sentRecipientIds = <String>[];
  final loadedPostcardIds = <String>[];
  final _persisted = <String, Postcard>{};
  var _nextId = 0;

  void storeReceived(Postcard postcard) => _persisted[postcard.id] = postcard;

  @override
  Future<Postcard> sendPostcard({
    required String recipientId,
    required String message,
  }) async {
    sentRecipientIds.add(recipientId);
    final postcard = Postcard(
      id: 'sent-${++_nextId}',
      message: message,
      createdAt: DateTime(2026, 11, 6),
      direction: PostcardDirection.sent,
      peerName: recipientId,
    );
    _persisted[postcard.id] = postcard;
    return postcard;
  }

  @override
  Future<Postcard?> loadReceivedPostcard(String postcardId) async {
    loadedPostcardIds.add(postcardId);
    return _persisted[postcardId];
  }

  @override
  Future<List<Postcard>> loadReceivedPostcards() async => _persisted.values
      .where((postcard) => postcard.direction == PostcardDirection.received)
      .toList();
}
