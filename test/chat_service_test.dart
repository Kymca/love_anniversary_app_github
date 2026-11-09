import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/chat_export.dart';
import 'package:love_anniversary_app/services/chat_service.dart';

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
