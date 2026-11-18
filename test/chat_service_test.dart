import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/chat_export.dart';
import 'package:love_anniversary_app/services/chat_export_storage.dart';
import 'package:love_anniversary_app/services/chat_service.dart';
import 'package:love_anniversary_app/services/telegram_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const exportJson = '''
  {
    "name": "Couple chat",
    "type": "personal_chat",
    "id": 42,
    "messages": [
      {"id": 1, "type": "message", "date": "2023-10-12T19:13:55", "date_unixtime": "1697130835", "from": "Alice", "from_id": "user1", "text": "Hello"},
      {"id": 2, "type": "message", "date": "2023-10-13T19:13:55", "date_unixtime": "1697224435", "from": "Bob", "from_id": "user2", "text": ["Hi ", {"type": "bold", "text": "Alice"}]},
      {"id": 3, "type": "service", "date": "2023-10-14T19:13:55", "date_unixtime": "1697310835", "actor": "Alice", "actor_id": "user1", "action": "pin_message", "text": "pinned a message"}
    ]
  }
  ''';

  test('parses Telegram message and service variants', () {
    final export = ChatExport.decode(exportJson);

    expect(export.name, 'Couple chat');
    expect(export.type, 'personal_chat');
    expect(export.id, 42);
    expect(export.messages, hasLength(3));
    expect(export.messages[1].text, 'Hi Alice');
    expect(export.messages[1].textEntities, hasLength(2));
    expect(export.messages[2].isService, isTrue);
    expect(export.messages[2].actor?.name, 'Alice');
    expect(export.messages[2].action, 'pin_message');
  });

  test(
    'safely flattens Telegram entities and preserves empty/service records',
    () {
      final export = ChatExport.decode('''
      {
        "name": "Synthetic chat",
        "type": "personal_chat",
        "id": 7,
        "messages": [
          {
            "id": 1,
            "type": "message",
            "from": "Alice",
            "text": ["Hello ", {"type": "bold", "text": "there"}, {"text": [" ", {"text": "friend"}]}]
          },
          {
            "id": 2,
            "type": "message",
            "from": "Bob",
            "text": "",
            "text_entities": ["Fallback text"]
          },
          {
            "id": 3,
            "type": "message",
            "from": "Alice",
            "text": ""
          },
          {
            "id": 4,
            "type": "service",
            "actor": "Bob",
            "action": "pin_message",
            "text": "pinned"
          }
        ]
      }
    ''');

      expect(export.messages.map((message) => message.text), [
        'Hello there friend',
        'Fallback text',
        '',
        'pinned',
      ]);
      expect(export.messages.last.isService, isTrue);
      expect(export.messages.last.actor?.name, 'Bob');
    },
  );

  test(
    'selects a balanced quote from synthetic Telegram export records',
    () async {
      final source = jsonEncode({
        'name': 'Synthetic couple chat',
        'type': 'personal_chat',
        'id': 42,
        'messages': [
          for (var index = 0; index < 6; index++)
            {
              'id': index + 1,
              'type': 'message',
              'date_unixtime': '${1697130835 + index * 60}',
              'from': index.isEven ? 'Alice' : 'Bob',
              'from_id': index.isEven ? 'user1' : 'user2',
              'text': index == 3
                  ? [
                      'Friendly ',
                      {'type': 'bold', 'text': 'message 3'},
                    ]
                  : 'Friendly message $index',
            },
        ],
      });
      final service = TelegramChatService(
        bundle: _StringAssetBundle(source),
        random: Random(0),
      );

      final quote = await service.getRandomSnippet();

      expect(quote.messages, hasLength(6));
      expect(quote.messages[3].text, 'Friendly message 3');
      expect(quote.messages.map((message) => message.author).toSet(), {
        'Alice',
        'Bob',
      });
    },
  );

  test(
    'imports and parses a synthetic export from local-only storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = _MemoryChatExportStorage();
      final service = TelegramChatService(
        preferences: preferences,
        localExportStorage: storage,
      );
      final source = jsonEncode({
        'name': 'Synthetic local chat',
        'type': 'personal_chat',
        'messages': [
          for (var index = 0; index < 6; index++)
            {
              'id': index + 1,
              'type': 'message',
              'date_unixtime': '${1697130835 + index * 60}',
              'from': index.isEven ? 'Alice' : 'Bob',
              'from_id': index.isEven ? 'user1' : 'user2',
              'text': 'Local synthetic message $index',
            },
        ],
      });

      await service.importLocalExport(Stream.value(utf8.encode(source)));

      expect(storage.source, source);
      expect(
        (await service.getRandomSnippet()).messages.first.text,
        startsWith('Local synthetic message'),
      );
      await expectLater(
        service.importLocalExport(Stream.value(utf8.encode('not JSON'))),
        throwsA(isA<FormatException>()),
      );
      expect(storage.source, source);
    },
  );

  test(
    'service loads once and provides dates and participant counts',
    () async {
      final bundle = _StringAssetBundle(exportJson);
      final service = ChatService(bundle: bundle);

      final messages = await service.getMessages();
      expect(messages, hasLength(3));
      expect(
        await service.getFirstMessageDate(),
        DateTime.fromMillisecondsSinceEpoch(1697130835 * 1000, isUtc: true),
      );
      expect(
        await service.getLastMessageDate(),
        DateTime.fromMillisecondsSinceEpoch(1697310835 * 1000, isUtc: true),
      );
      expect(await service.getMessageCountsByParticipant(), {
        'Alice': 1,
        'Bob': 1,
      });
      expect(bundle.loadCount, 1);
    },
  );
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.source);

  final String source;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount++;
    final bytes = utf8.encode(source);
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

class _MemoryChatExportStorage implements ChatExportStorage {
  String? source;

  @override
  Future<String?> read() async => source;

  @override
  Future<ChatExport> importExport(
    Stream<List<int>> bytes,
    Future<ChatExport> Function(String source) decode,
  ) async {
    final incoming = await utf8.decoder.bind(bytes).join();
    final export = await decode(incoming);
    source = incoming;
    return export;
  }
}
