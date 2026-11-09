import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/pair_room.dart';
import 'package:love_anniversary_app/screens/pairs_screen.dart';
import 'package:love_anniversary_app/services/pair_repository.dart';
import 'package:love_anniversary_app/services/participant_profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('in-memory repository creates a unique four-digit pair code', () async {
    final repository = InMemoryPairRepository();
    final first = await repository.createPair('  Алина ');
    final second = await repository.createPair('Саша');

    expect(first.code, matches(RegExp(r'^\d{4}$')));
    expect(second.code, matches(RegExp(r'^\d{4}$')));
    expect(second.code, isNot(first.code));
    expect(first.members.single.name, 'Алина');
    expect(first.members, hasLength(1));
    expect((await repository.loadActivePair())?.code, second.code);
  });

  test('joining validates name and code and creates two-member room', () async {
    final repository = InMemoryPairRepository();
    final room = await repository.createPair('Алина');

    await expectLater(
      repository.createPair('  '),
      throwsA(isA<PairRepositoryException>()),
    );
    await expectLater(
      repository.joinPair('', room.code),
      throwsA(isA<PairRepositoryException>()),
    );
    await expectLater(
      repository.joinPair('Саша', '12'),
      throwsA(isA<PairRepositoryException>()),
    );
    await expectLater(
      repository.joinPair('Саша', '0000'),
      throwsA(isA<PairRepositoryException>()),
    );

    final joined = await repository.joinPair('Саша', room.code);
    expect(joined.members.map((member) => member.name), ['Алина', 'Саша']);
    expect((await repository.loadActivePair())?.code, room.code);
    await expectLater(
      repository.joinPair('Кто-то ещё', room.code),
      throwsA(isA<PairRepositoryException>()),
    );
  });

  test('shared-preferences repository restores local room state', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final firstRepository = SharedPreferencesPairRepository(
      preferences: preferences,
    );
    final created = await firstRepository.createPair('Алина');
    final secondRepository = SharedPreferencesPairRepository(
      preferences: preferences,
    );

    final found = await secondRepository.findPair(created.code);
    expect(found?.members.single.name, 'Алина');
    expect((await secondRepository.loadActivePair())?.code, created.code);
    final joined = await secondRepository.joinPair('Саша', created.code);
    expect(joined.members, hasLength(2));
    expect(
      (await firstRepository.findPair(created.code))?.members.last.name,
      'Саша',
    );
  });

  testWidgets('pair screen creates and shares code then allows joining', (
    tester,
  ) async {
    final repository = InMemoryPairRepository();
    final preferences = await SharedPreferences.getInstance();
    final profileRepository = ParticipantProfileRepository(
      preferences: preferences,
    );
    await profileRepository.saveName('first', 'Алина');
    await profileRepository.saveName('second', 'Саша');
    await tester.pumpWidget(
      localizedTestApp(
        home: PairsScreen(
          repository: repository,
          profileRepository: profileRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Данные пары сохраняются только на этом устройстве.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('Создать пару'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Код локальной пары (тест)'), findsOneWidget);
    final code = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data;
    expect(code, matches(RegExp(r'^\d{4}$')));
    await tester.tap(find.text('Готово'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, code!);
    await tester.tap(find.text('Присоединиться'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ваша пара'), findsOneWidget);
    expect(find.text('Алина'), findsWidgets);
    expect(find.widgetWithText(ListTile, 'Саша'), findsOneWidget);
    expect(find.textContaining('настроенный сервер'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('pair room model rejects malformed persisted data', () {
    expect(
      () => PairRoom.fromJson({'code': '123', 'members': <Object?>[]}),
      throwsFormatException,
    );
  });
}
