import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_mood.dart';
import 'mood_pair_repository.dart';
import 'pair_repository.dart';

class SupabaseMoodPairRepository implements MoodPairRepository {
  SupabaseMoodPairRepository(this.client, this.pairRepository);

  final SupabaseClient client;
  final PairRepository pairRepository;

  @override
  bool get isSynchronized => true;

  @override
  Future<DailyPairMood> loadFor(DateTime date) async {
    final context = await _loadPairContext();
    final rows = await client
        .from('pair_daily_moods')
        .select('participant_user_id, mood')
        .eq('pair_id', context.pairId)
        .eq('date_key', moodDateKey(date))
        .order('recorded_at');
    return _dailyMood(rows, context.userSides, date);
  }

  @override
  Stream<DailyPairMood> watchFor(DateTime date) async* {
    final context = await _loadPairContext();
    yield* client
        .from('pair_daily_moods')
        .stream(primaryKey: ['id'])
        .eq('pair_id', context.pairId)
        .eq('date_key', moodDateKey(date))
        .map((rows) => _dailyMood(rows, context.userSides, date));
  }

  @override
  Stream<void> watchChanges() async* {
    final context = await _loadPairContext();
    yield* client
        .from('pair_daily_moods')
        .stream(primaryKey: ['id'])
        .eq('pair_id', context.pairId)
        .map((_) {});
  }

  @override
  Future<List<DailyMoodEntry>> historyFor(
    String participant,
    DateTime date,
  ) async {
    final context = await _loadPairContext();
    final userId = _maybeUserIdForSide(context, participant);
    if (userId == null) return const [];
    final rows = await client
        .from('pair_daily_moods')
        .select('date_key, mood, compliment, recorded_at')
        .eq('pair_id', context.pairId)
        .eq('participant_user_id', userId)
        .eq('date_key', moodDateKey(date))
        .order('recorded_at');
    return _entries(rows);
  }

  @override
  Future<List<DailyMoodEntry>> historyForParticipant(String participant) async {
    final context = await _loadPairContext();
    final userId = _maybeUserIdForSide(context, participant);
    if (userId == null) return const [];
    final rows = await client
        .from('pair_daily_moods')
        .select('date_key, mood, compliment, recorded_at')
        .eq('pair_id', context.pairId)
        .eq('participant_user_id', userId)
        .order('date_key')
        .order('recorded_at');
    return _entries(rows);
  }

  @override
  Future<DailyPairMood> record(
    String participant,
    DailyMood mood, {
    required DateTime date,
  }) async {
    final context = await _loadPairContext();
    final userId = _userIdForSide(context, participant);
    if (context.currentUserId != userId) {
      throw StateError('A participant cannot change the partner mood.');
    }
    final dateKey = moodDateKey(date);
    await client.from('pair_daily_moods').insert({
      'pair_id': context.pairId,
      'participant_user_id': userId,
      'date_key': dateKey,
      'mood': mood.name,
      'compliment': mood.complimentFor(dateKey),
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    });
    return loadFor(date);
  }

  Future<_PairMoodContext> _loadPairContext() async {
    final pair = await pairRepository.loadActivePair();
    final pairId = pair?.id;
    if (pairId == null) throw StateError('Join a pair to share moods.');
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw AuthSessionMissingException('Sign in to share pair moods.');
    }
    final row = await client
        .from('pairs')
        .select('first_user_id, second_user_id')
        .eq('id', pairId)
        .single();
    final firstUserId = row['first_user_id'];
    final secondUserId = row['second_user_id'];
    if (firstUserId is! String ||
        (secondUserId != null && secondUserId is! String)) {
      throw const FormatException('Backend returned invalid pair members.');
    }
    final userSides = <String, String>{firstUserId: 'first'};
    if (secondUserId is String) userSides[secondUserId] = 'second';
    if (!userSides.containsKey(currentUserId)) {
      throw StateError('The current user is not a member of this pair.');
    }
    return _PairMoodContext(
      pairId: pairId,
      currentUserId: currentUserId,
      userSides: userSides,
    );
  }

  String _userIdForSide(_PairMoodContext context, String side) {
    if (side != 'first' && side != 'second') {
      throw ArgumentError.value(side, 'participant');
    }
    for (final entry in context.userSides.entries) {
      if (entry.value == side) return entry.key;
    }
    throw StateError('The pair does not have a $side participant yet.');
  }

  String? _maybeUserIdForSide(_PairMoodContext context, String side) {
    if (side != 'first' && side != 'second') {
      throw ArgumentError.value(side, 'participant');
    }
    for (final entry in context.userSides.entries) {
      if (entry.value == side) return entry.key;
    }
    return null;
  }

  DailyPairMood _dailyMood(
    List<Map<String, dynamic>> rows,
    Map<String, String> userSides,
    DateTime date,
  ) {
    final moods = <String, DailyMood>{};
    final recordedAtBySide = <String, DateTime>{};
    for (final row in rows) {
      final side = userSides[row['participant_user_id']];
      final moodName = row['mood'];
      final recordedAtValue = row['recorded_at'];
      if (side == null) continue;
      if (moodName is! String || recordedAtValue is! String) {
        throw const FormatException('Backend returned invalid pair mood.');
      }
      final recordedAt = DateTime.tryParse(recordedAtValue);
      if (recordedAt == null) {
        throw const FormatException('Backend returned invalid mood timestamp.');
      }
      final matches = DailyMood.values.where((value) => value.name == moodName);
      if (matches.isEmpty) {
        throw const FormatException('Backend returned an unknown mood.');
      }
      final previous = recordedAtBySide[side];
      if (previous == null || recordedAt.isAfter(previous)) {
        moods[side] = matches.first;
        recordedAtBySide[side] = recordedAt;
      }
    }
    return DailyPairMood(dateKey: moodDateKey(date), moods: moods);
  }

  List<DailyMoodEntry> _entries(List<Map<String, dynamic>> rows) {
    final entries = <DailyMoodEntry>[];
    for (final row in rows) {
      final dateKey = row['date_key'];
      final moodName = row['mood'];
      final compliment = row['compliment'];
      final recordedAt = row['recorded_at'];
      if (dateKey is! String ||
          moodName is! String ||
          compliment is! String ||
          recordedAt is! String) {
        throw const FormatException('Backend returned invalid mood history.');
      }
      final mood = DailyMood.values.where((value) => value.name == moodName);
      if (mood.isEmpty) {
        throw const FormatException('Backend returned an unknown mood.');
      }
      entries.add(
        DailyMoodEntry(
          dateKey: dateKey,
          mood: mood.first,
          compliment: compliment,
          recordedAt: DateTime.parse(recordedAt),
        ),
      );
    }
    return List.unmodifiable(entries);
  }
}

class _PairMoodContext {
  const _PairMoodContext({
    required this.pairId,
    required this.currentUserId,
    required this.userSides,
  });

  final String pairId;
  final String currentUserId;
  final Map<String, String> userSides;
}
