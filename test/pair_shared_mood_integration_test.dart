import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_anniversary_app/models/daily_mood.dart';
import 'package:love_anniversary_app/models/pair_room.dart';
import 'package:love_anniversary_app/screens/tamagotchi_screen.dart';
import 'package:love_anniversary_app/services/duck_name_repository.dart';
import 'package:love_anniversary_app/services/duck_ownership_repository.dart';
import 'package:love_anniversary_app/services/mood_pair_repository.dart';
import 'package:love_anniversary_app/services/pair_repository.dart';
import 'package:love_anniversary_app/services/participant_profile_repository.dart';
import 'package:love_anniversary_app/widgets/duck_mood.dart';
import 'package:love_anniversary_app/widgets/duck_sprite.dart';
import 'package:love_anniversary_app/widgets/mood_envelope.dart';
import 'package:love_anniversary_app/widgets/mood_pair_widget.dart';
import 'package:love_anniversary_app/widgets/mood_calendar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'partner mood update reaches the duck sprite and incoming envelope',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backend = _SharedMoodBackend();
      final firstUser = _SharedMoodRepository(backend, 'first');
      final secondUser = _SharedMoodRepository(backend, 'second');
      await SharedPreferences.getInstance();

      await tester.pumpWidget(
        localizedTestApp(
          home: TamagotchiScreen(
            pairRepository: _SharedPairRepository(),
            moodPairRepository: secondUser,
            ownershipRepository: _PartnerOwnsDuck(),
            duckNameRepository: _TestDuckNameRepository(),
            partnerSide: DuckPartnerSide.second,
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byType(DuckSpriteWidget), findsOneWidget);
      expect(
        tester.widget<DuckSpriteWidget>(find.byType(DuckSpriteWidget)).emotion,
        DuckEmotion.neutral,
      );

      await firstUser.record('first', DailyMood.angry, date: DateTime.now());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.widget<DuckSpriteWidget>(find.byType(DuckSpriteWidget)).emotion,
        DuckEmotion.angry,
      );
      expect(find.byType(MoodIncomingEnvelope), findsOneWidget);
      expect(
        tester
            .widget<MoodIncomingEnvelope>(find.byType(MoodIncomingEnvelope))
            .mood,
        DailyMood.angry,
      );
      expect(
        find.text('Имя уточки синхронизируется между участниками пары.'),
        findsOneWidget,
      );
      expect(
        find.text('Настроения синхронизируются между участниками пары.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'calendar shows partner mood and its selection updates shared pair mood',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final preferences = await SharedPreferences.getInstance();
      final profiles = ParticipantProfileRepository(preferences: preferences);
      await profiles.saveCurrentSide('second');
      final backend = _SharedMoodBackend();
      final firstUser = _SharedMoodRepository(backend, 'first');
      final secondUser = _SharedMoodRepository(backend, 'second');
      final today = DateTime.now();
      await firstUser.record('first', DailyMood.angry, date: today);

      await tester.pumpWidget(
        localizedTestApp(
          home: Scaffold(
            body: ListView(
              children: [
                MoodPairWidget(
                  repository: secondUser,
                  participantSide: 'second',
                  participantNames: const {
                    'first': 'Алина',
                    'second': 'Руслан',
                  },
                ),
                MoodCalendarWidget(
                  repository: secondUser,
                  profileRepository: profiles,
                  pairRepository: _SharedPairRepository(),
                  clock: () => today,
                ),
              ],
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(const ValueKey('partner-today-mood')), findsOneWidget);
      expect(
        (tester.widget<Text>(find.byKey(const ValueKey('partner-today-mood'))))
            .data,
        contains('😠'),
      );
      final choice = find.byKey(const ValueKey('mood-calendar-choice-joyful'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await _pumpFrames(tester);

      expect(
        (await firstUser.loadFor(today)).moods['second'],
        DailyMood.joyful,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('mood-choice-second-joyful')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 12; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _SharedMoodBackend {
  final Map<String, List<DailyMoodEntry>> entries = {};
  final StreamController<DailyPairMood> changes =
      StreamController<DailyPairMood>.broadcast(sync: true);
}

class _SharedMoodRepository implements MoodPairRepository {
  _SharedMoodRepository(this.backend, this.currentSide);

  final _SharedMoodBackend backend;
  final String currentSide;

  @override
  bool get isSynchronized => true;

  String _key(String side, String date) => '$side:$date';

  @override
  Future<DailyPairMood> loadFor(DateTime date) async {
    final dateKey = moodDateKey(date);
    final moods = <String, DailyMood>{};
    for (final side in const ['first', 'second']) {
      final history = backend.entries[_key(side, dateKey)];
      if (history?.isNotEmpty ?? false) moods[side] = history!.last.mood;
    }
    return DailyPairMood(dateKey: dateKey, moods: moods);
  }

  @override
  Future<List<DailyMoodEntry>> historyFor(
    String participant,
    DateTime date,
  ) async => List.unmodifiable(
    backend.entries[_key(participant, moodDateKey(date))] ?? const [],
  );

  @override
  Future<List<DailyMoodEntry>> historyForParticipant(String participant) async {
    final history = [
      for (final entry in backend.entries.entries)
        if (entry.key.startsWith('$participant:')) ...entry.value,
    ]..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return List.unmodifiable(history);
  }

  @override
  Stream<void> watchChanges() => backend.changes.stream.map((_) {});

  @override
  Stream<DailyPairMood> watchFor(DateTime date) async* {
    final dateKey = moodDateKey(date);
    yield await loadFor(date);
    yield* backend.changes.stream.where((mood) => mood.dateKey == dateKey);
  }

  @override
  Future<DailyPairMood> record(
    String participant,
    DailyMood mood, {
    required DateTime date,
  }) async {
    if (participant != currentSide) {
      throw StateError('A user cannot update the other participant mood.');
    }
    final dateKey = moodDateKey(date);
    final entry = DailyMoodEntry(
      dateKey: dateKey,
      mood: mood,
      compliment: mood.complimentFor(dateKey),
      recordedAt: DateTime.now(),
    );
    backend.entries
        .putIfAbsent(_key(participant, dateKey), () => [])
        .add(entry);
    final pairMood = await loadFor(date);
    backend.changes.add(pairMood);
    return pairMood;
  }
}

class _SharedPairRepository implements PairRepository {
  static const room = PairRoom(
    id: 'shared-pair-id',
    code: '1234',
    members: [
      PairMember(name: 'Алина'),
      PairMember(name: 'Руслан'),
    ],
  );

  @override
  Future<PairRoom> createPair(String name) => throw UnimplementedError();

  @override
  Future<void> deletePair(PairRoom room) => throw UnimplementedError();

  @override
  Future<PairRoom?> loadActivePair() async => room;

  @override
  Future<PairRoom> joinPair(String name, String code) =>
      throw UnimplementedError();
}

class _PartnerOwnsDuck implements DuckOwnershipService {
  @override
  Future<bool> isCurrentParticipantOwner(DateTime date) async => false;

  @override
  Future<String> ownerFor(DateTime date) async => 'first';

  @override
  Future<String> requireCurrentOwner(DateTime date) async => 'first';

  @override
  Future<void> requireParticipantSide(String side) async {}
}

class _TestDuckNameRepository implements DuckNameRepository {
  @override
  bool get isSynchronized => true;

  @override
  Future<bool> claimNamingPrompt(String? pairId) async => false;

  @override
  Future<String?> loadName(String? pairId) async => 'Кряква';

  @override
  Future<String> saveName(String? pairId, String name) async => name;

  @override
  Stream<String?> watchName(String? pairId) => const Stream.empty();
}
