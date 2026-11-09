import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/pair_room.dart';
import 'package:love_anniversary_app/services/participant_profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('names persist independently for both participant sides', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = ParticipantProfileRepository(preferences: preferences);

    await repository.saveName('first', 'Алина');
    await repository.saveName('second', 'Саша');

    expect(await repository.loadNames(), {'first': 'Алина', 'second': 'Саша'});
  });

  test(
    'legacy pair member names migrate into side-specific profile keys',
    () async {
      final preferences = await SharedPreferences.getInstance();
      const pair = PairRoom(
        code: '1234',
        members: [
          PairMember(name: 'Алина'),
          PairMember(name: 'Саша'),
        ],
      );
      final repository = ParticipantProfileRepository(preferences: preferences);

      expect(await repository.loadNames(pair: pair), {
        'first': 'Алина',
        'second': 'Саша',
      });
      expect(
        preferences.getString(ParticipantProfileRepository.firstNameKey),
        'Алина',
      );
      expect(
        preferences.getString(ParticipantProfileRepository.secondNameKey),
        'Саша',
      );
    },
  );
}
