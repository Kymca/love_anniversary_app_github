import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/services/telegram_chat_service.dart';

import 'test_app.dart';

import 'package:love_anniversary_app/widgets/random_memories_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'selects a date-stable daily quote from a synthetic export',
    () async {
      final service = _service(_balancedExport(12));
      final lateOnDay = DateTime(2026, 11, 14, 23, 59);
      final first = await service.getDailySnippet(date: lateOnDay);
      final sameDay = await service.getDailySnippet(
        date: DateTime(2026, 11, 14, 7),
      );
      final nextDay = await service.getDailySnippet(
        date: DateTime(2026, 11, 15, 0, 1),
      );

      expect(first.messages.length, inInclusiveRange(6, 10));
      expect(sameDay.id, first.id);
      expect(nextDay.id, isNot(first.id));
      final authorCounts = <String, int>{};
      for (final message in first.messages) {
        expect(message.text.trim(), isNotEmpty);
        expect(message.timestamp, isNotNull);
        expect(
          TelegramChatService.negativeTriggers.any(
            (trigger) => message.text.toLowerCase().contains(trigger),
          ),
          isFalse,
        );
        authorCounts.update(
          message.author,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      expect(authorCounts, hasLength(2));
      expect(authorCounts.values, everyElement(greaterThanOrEqualTo(3)));
    },
  );

  test('rebuilds same-day daily quote cache from an updated export', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      TelegramChatService.dailySnippetKey,
      jsonEncode({
        'date': '2024-01-01',
        'snippet': {'id': 'old-export-snippet', 'messages': <Object?>[]},
      }),
    );
    final service = _service(
      _balancedExport(12),
      preferences: preferences,
      random: _FirstWindowRandom(),
    );

    final snippet = await service.getDailySnippet(date: DateTime(2024, 1, 1));

    expect(snippet.id, isNot('old-export-snippet'));
    expect(snippet.messages.length, inInclusiveRange(6, 10));
    final savedCache = jsonDecode(
      preferences.getString(TelegramChatService.dailySnippetKey)!,
    ) as Map<String, dynamic>;
    expect(savedCache['exportFingerprint'], startsWith('balanced-window-v1:'));
  });

  test('returns an immutable balanced contiguous conversation', () async {
    final service = _service(_balancedExport(12), random: _FirstWindowRandom());

    final snippet = await service.getRandomSnippet();

    expect(snippet.messages, hasLength(6));
    expect(snippet.messages.map((message) => message.text), [
      for (var index = 0; index < 6; index++) 'Friendly message $index',
    ]);
    expect(snippet.messages.map((message) => message.author), [
      'Alex',
      'Sam',
      'Alex',
      'Sam',
      'Alex',
      'Sam',
    ]);
    expect(snippet.messages.first.timestamp, isNotNull);
    expect(
      () => snippet.messages.add(snippet.messages.first),
      throwsUnsupportedError,
    );
  });

  test('rejects single-author and imbalanced histories', () async {
    final singleAuthor = _service(
      _export([
        for (var index = 0; index < 8; index++) _message('Alex', index),
      ]),
    );
    final imbalanced = _service(
      _export([
        for (var index = 0; index < 10; index++) _message('Alex', index),
        _message('Sam', 10),
        _message('Sam', 11),
      ]),
    );

    await expectLater(
      singleAuthor.getRandomSnippet(),
      throwsA(isA<NoEligibleMemoryException>()),
    );
    await expectLater(
      imbalanced.getRandomSnippet(),
      throwsA(isA<NoEligibleMemoryException>()),
    );
  });

  test(
    'filters every configured negative trigger case-insensitively',
    () async {
      for (final trigger in TelegramChatService.negativeTriggers) {
        final messages = _balancedMessages(6);
        messages[2]['text'] = 'A synthetic phrase: ${trigger.toUpperCase()}!';
        final service = _service(_export(messages));

        await expectLater(
          service.getRandomSnippet(),
          throwsA(isA<NoEligibleMemoryException>()),
          reason: 'Trigger "$trigger" should exclude the conversation.',
        );
      }
    },
  );

  test(
    'matches multiword triggers but not words inside larger words',
    () async {
      final negativeMessages = _balancedMessages(6);
      negativeMessages[0]['text'] = 'Пожалуйста, НЕ   ПИШИ   мне.';
      await expectLater(
        _service(_export(negativeMessages)).getRandomSnippet(),
        throwsA(isA<NoEligibleMemoryException>()),
      );

      final benignMessages = _balancedMessages(6);
      benignMessages[0]['text'] = 'Простирадло лежит на кровати.';
      final snippet = await _service(_export(benignMessages))
          .getRandomSnippet();
      expect(snippet.messages, hasLength(6));

      final triggerInsideWordMessages = _balancedMessages(6);
      triggerInsideWordMessages[0]['text'] = 'Непишимне и поругалисья.';
      expect(
        (await _service(
          _export(triggerInsideWordMessages),
        ).getRandomSnippet()).messages,
        hasLength(6),
      );

      final contextualPhraseMessages = _balancedMessages(6);
      contextualPhraseMessages[5]['text'] = 'Хватит   писать!';
      await expectLater(
        _service(_export(contextualPhraseMessages)).getRandomSnippet(),
        throwsA(isA<NoEligibleMemoryException>()),
      );
    },
  );

  test(
    'allows payment wording but excludes a negative context phrase',
    () async {
      final paymentMessages = _balancedMessages(6);
      paymentMessages[0]['text'] = 'Плачу за покупку картой.';
      expect(
        (await _service(_export(paymentMessages)).getRandomSnippet()).messages,
        hasLength(6),
      );

      final negativeMessages = _balancedMessages(6);
      negativeMessages[0]['text'] = 'ПЛАЧУ   ИЗ-ЗА этой ситуации.';
      await expectLater(
        _service(_export(negativeMessages)).getRandomSnippet(),
        throwsA(isA<NoEligibleMemoryException>()),
      );
    },
  );

  test('does not bridge service, action, or blank rows', () async {
    final messages = [
      ..._balancedMessages(3),
      {'type': 'service', 'action': 'pin_message', 'text': 'Synthetic event'},
      ..._balancedMessages(3).map((message) {
        return {...message, 'id': (message['id'] as int) + 10};
      }),
    ];

    await expectLater(
      _service(_export(messages)).getRandomSnippet(),
      throwsA(isA<NoEligibleMemoryException>()),
    );
  });

  test('samples distinct eligible windows', () async {
    final source = _balancedExport(12);
    final first = await _service(
      source,
      random: _FirstWindowRandom(),
    ).getRandomSnippet();
    final last = await _service(
      source,
      random: _LastWindowRandom(),
    ).getRandomSnippet();

    expect(first.messages.first.text, 'Friendly message 0');
    expect(last.messages.first.text, 'Friendly message 6');
    expect(first.id, isNot(last.id));
  });

  test('throws a descriptive error when no eligible window exists', () async {
    final service = _service(
      _export([
        {'type': 'service', 'text': 'Synthetic service event'},
        _message('Alex', 1, text: '   '),
      ]),
    );

    await expectLater(
      service.getRandomSnippet(),
      throwsA(
        isA<NoEligibleMemoryException>().having(
          (error) => error.message,
          'message',
          contains('6–10 consecutive'),
        ),
      ),
    );
  });

  test('persists and removes favorites by stable snippet id', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final service = _service(
      _balancedExport(12),
      random: _FirstThenLastRandom(),
      preferences: preferences,
    );

    final first = await service.getRandomSnippet();
    final second = await service.getRandomSnippet();
    expect(second.id, isNot(first.id));

    expect(await service.toggleFavorite(first), isTrue);
    expect(await service.isFavorite(first), isTrue);
    expect((await service.getFavorites()).single.id, first.id);
    expect(await service.toggleFavorite(first), isFalse);
    expect(await service.getFavorites(), isEmpty);
  });

  testWidgets('card shows a calm empty state when no memory is eligible', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(
          body: RandomMemoriesCard(
            service: _service(
              _export([
                for (var index = 0; index < 10; index++)
                  _message('Alex', index),
                _message('Sam', 10),
                _message('Sam', 11),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Подходящего воспоминания пока нет.'), findsOneWidget);
    expect(
      find.text(
        'Не получилось загрузить воспоминание. Проверьте файл экспорта чата.',
      ),
      findsNothing,
    );
    expect(find.text('Показать другой момент'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card treats missing and invalid exports as an empty state', (
    tester,
  ) async {
    for (final service in [
      _service('not valid json'),
      TelegramChatService(bundle: _MissingAssetBundle()),
    ]) {
      await tester.pumpWidget(
        localizedTestApp(
          home: Scaffold(body: RandomMemoriesCard(service: service)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Подходящего воспоминания пока нет.'), findsOneWidget);
      expect(
        find.text(
          'Не получилось загрузить воспоминание. Проверьте файл экспорта чата.',
        ),
        findsNothing,
      );
      expect(find.text('Показать другой момент'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('card refreshes animated memories and toggles favorites', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final service = _service(
      _balancedExport(12),
      random: _FirstWindowRandom(),
      preferences: preferences,
    );
    final dailySnippet = await service.getDailySnippet();
    final anotherSnippet = await service.getRandomSnippet();

    await tester.pumpWidget(
      localizedTestApp(
        home: Scaffold(body: RandomMemoriesCard(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(dailySnippet.messages.first.text), findsOneWidget);

    await tester.tap(find.byTooltip('Добавить в избранное'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Убрать из избранного'), findsOneWidget);
    expect(preferences.getString(TelegramChatService.favoritesKey), isNotNull);

    await tester.tap(find.text('Показать другой момент'));
    await tester.pumpAndSettle();
    expect(find.text(anotherSnippet.messages.first.text), findsOneWidget);
  });
}

TelegramChatService _service(
  String exportJson, {
  Random? random,
  SharedPreferences? preferences,
}) {
  return TelegramChatService(
    bundle: _StringAssetBundle(exportJson),
    random: random,
    preferences: preferences,
  );
}

String _balancedExport(int count) => _export(_balancedMessages(count));

List<Map<String, Object?>> _balancedMessages(int count) {
  return [
    for (var index = 0; index < count; index++)
      _message(index.isEven ? 'Alex' : 'Sam', index),
  ];
}

Map<String, Object?> _message(String author, int index, {String? text}) {
  final participantId = author == 'Alex' ? 1 : 2;
  return {
    'id': index + 1,
    'type': 'message',
    'date': '2024-01-01T12:${index.toString().padLeft(2, '0')}:00',
    'from': author,
    'from_id': 'user-$participantId',
    'text': text ?? 'Friendly message $index',
  };
}

String _export(List<Map<String, Object?>> messages) {
  return jsonEncode({
    'id': 42,
    'name': 'Synthetic chat',
    'type': 'personal_chat',
    'messages': messages,
  });
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  }
}

class _MissingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw FlutterError('Unable to load asset: $key');
  }
}

class _FirstWindowRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => max - 1;
}

class _LastWindowRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

class _FirstThenLastRandom implements Random {
  var _calls = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) {
    final index = _calls == 0
        ? 0
        : _calls < 25
        ? 1
        : 0;
    _calls++;
    return index.clamp(0, max - 1).toInt();
  }
}
