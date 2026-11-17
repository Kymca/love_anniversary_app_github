import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/services/duck_ownership_repository.dart';
import 'package:love_anniversary_app/services/participant_profile_repository.dart';
import 'package:love_anniversary_app/services/warehouse_work_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'daily owner persists across repository instances and alternates by day',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final profiles = ParticipantProfileRepository(preferences: preferences);
      final ownership = DuckOwnershipRepository(
        preferences: preferences,
        profileRepository: profiles,
      );
      final today = DateTime(2026, 11, 9);

      expect(await ownership.ownerFor(today), 'first');
      expect(
        await DuckOwnershipRepository(
          preferences: preferences,
          profileRepository: profiles,
        ).ownerFor(today),
        'first',
      );
      expect(
        await ownership.ownerFor(today.add(const Duration(days: 1))),
        'second',
      );

      await profiles.saveCurrentSide('first');
      expect(await ownership.isCurrentParticipantOwner(today), isTrue);
      await expectLater(
        ownership.requireCurrentOwner(today.add(const Duration(days: 1))),
        throwsA(isA<DuckNotOwnedException>()),
      );
      await profiles.saveCurrentSide('second');
      expect(
        await ownership.requireCurrentOwner(today.add(const Duration(days: 1))),
        'second',
      );
      await profiles.saveCurrentSide('first');
      expect(
        await ownership.isCurrentParticipantOwner(
          today.add(const Duration(days: 1)),
        ),
        isFalse,
      );
    },
  );

  test('warehouse repository rejects starting work for a non-owner', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final profiles = ParticipantProfileRepository(preferences: preferences);
    await profiles.saveCurrentSide('second');
    final ownership = DuckOwnershipRepository(
      preferences: preferences,
      profileRepository: profiles,
    );
    final repository = WarehouseWorkRepository(
      preferences: preferences,
      clock: () => DateTime(2026, 11, 9, 10),
      ownershipRepository: ownership,
    );

    await expectLater(
      repository.beginWork(),
      throwsA(isA<DuckNotOwnedException>()),
    );
  });
}
