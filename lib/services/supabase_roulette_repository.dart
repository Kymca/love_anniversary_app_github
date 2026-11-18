import 'package:supabase_flutter/supabase_flutter.dart';

import 'roulette_repository.dart';

class SupabaseRouletteRepository implements RouletteRepository {
  SupabaseRouletteRepository({
    required this.client,
    required this.activePairId,
  });

  final SupabaseClient client;
  final Future<String?> Function() activePairId;

  Future<String?> _pairId() => activePairId();

  @override
  Future<List<String>> loadSharedChoices(RouletteCategory category) async {
    final id = await _pairId();
    if (id == null) return const [];
    final rows = await client
        .from('pair_roulette_choices')
        .select('choice')
        .eq('pair_id', id)
        .eq('category', category.name)
        .order('created_at');
    return List.unmodifiable(rows.map((row) => row['choice'] as String));
  }

  @override
  Future<List<String>> loadCustomChoices(RouletteCategory category) async {
    final id = await _pairId();
    if (id == null) return const [];
    final excluded = (await loadExcludedChoiceKeys(category)).toSet();
    final rows = await client
        .from('pair_roulette_choices')
        .select('choice')
        .eq('pair_id', id)
        .eq('category', category.name)
        .eq('is_active', true)
        .order('created_at');
    return List.unmodifiable(
      rows
          .map((row) => row['choice'] as String)
          .where(
            (choice) => !excluded.contains(
              SharedPreferencesRouletteRepository.customChoiceKey(choice),
            ),
          ),
    );
  }

  @override
  Future<List<String>> loadExcludedChoiceKeys(RouletteCategory category) async {
    final id = await _pairId();
    if (id == null) return const [];
    // The deployed RPC has ambiguous output-column names in its update filter.
    final rows = await client
        .from('pair_roulette_exclusions')
        .select('choice_key, watched, excluded_until')
        .eq('pair_id', id)
        .eq('category', category.name);
    final now = DateTime.now().toUtc();
    return List.unmodifiable(
      rows.map((row) {
        final choiceKey = row['choice_key'];
        final watched = row['watched'];
        final excludedUntilValue = row['excluded_until'];
        if (choiceKey is! String ||
            watched is! bool ||
            (excludedUntilValue != null && excludedUntilValue is! String)) {
          throw const FormatException(
            'Backend returned an invalid roulette exclusion.',
          );
        }
        final excludedUntil = excludedUntilValue is String
            ? DateTime.tryParse(excludedUntilValue)?.toUtc()
            : null;
        final isExpiredMovie =
            category == RouletteCategory.movie &&
            !watched &&
            excludedUntil != null &&
            !excludedUntil.isAfter(now);
        final isActiveTimedChoice =
            category != RouletteCategory.movie &&
            excludedUntil != null &&
            excludedUntil.isAfter(now);
        return watched || isExpiredMovie || isActiveTimedChoice
            ? choiceKey
            : null;
      }).whereType<String>(),
    );
  }

  @override
  Future<void> addChoice(RouletteCategory category, String choice) async {
    final value = choice.trim();
    if (value.isEmpty || value.length > 80) {
      throw ArgumentError.value(choice, 'choice');
    }
    final pairId =
        await _pairId() ??
        (throw StateError('Join a pair before syncing roulette choices.'));
    await client.from('pair_roulette_choices').upsert({
      'pair_id': pairId,
      'category': category.name,
      'choice': value,
      'is_active': true,
    }, onConflict: 'pair_id,category,normalized_choice');
  }

  @override
  Future<void> removeChoice(RouletteCategory category, String choice) async {
    final pairId =
        await _pairId() ??
        (throw StateError('Join a pair before syncing roulette choices.'));
    await client
        .from('pair_roulette_choices')
        .update({'is_active': false})
        .eq('pair_id', pairId)
        .eq('category', category.name)
        .eq('normalized_choice', choice.trim().toLowerCase());
  }

  @override
  Future<void> applyChoice(
    RouletteCategory category,
    String choice,
    String choiceKey,
  ) async {
    final pairId =
        await _pairId() ??
        (throw StateError('Join a pair before syncing roulette choices.'));
    await client.rpc(
      'apply_pair_roulette_choice',
      params: {
        'p_pair_id': pairId,
        'p_category': category.name,
        'p_choice': choice,
        'p_choice_key': choiceKey,
      },
    );
  }

  @override
  Future<RouletteSpin?> startSpin(
    RouletteCategory category,
    String choice,
    String choiceKey,
  ) async {
    final pairId = await _pairId();
    if (pairId == null) {
      return SharedPreferencesRouletteRepository().startSpin(
        category,
        choice,
        choiceKey,
      );
    }
    final result = await client.rpc(
      'start_pair_roulette_spin',
      params: {
        'p_pair_id': pairId,
        'p_category': category.name,
        'p_choice': choice,
        'p_choice_key': choiceKey,
      },
    );
    if (result == null) return null;
    if (result is! Map) {
      throw const FormatException('Backend returned an invalid roulette spin.');
    }
    return RouletteSpin.fromJson(Map<String, dynamic>.from(result));
  }

  @override
  Stream<void> watchChanges(RouletteCategory category) async* {
    final pairId = await _pairId();
    if (pairId == null) return;
    final libraryChanges = client
        .from('pair_roulette_choices')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .eq('category', category.name);
    final exclusionChanges = client
        .from('pair_roulette_exclusions')
        .stream(primaryKey: ['pair_id', 'category', 'choice_key'])
        .eq('pair_id', pairId)
        .eq('category', category.name);

    yield* Stream<void>.multi((controller) {
      void notify(Object? _) => controller.add(null);
      void reportError(Object error, StackTrace stackTrace) =>
          controller.addError(error, stackTrace);
      final subscriptions = [
        libraryChanges.listen(notify, onError: reportError),
        exclusionChanges.listen(notify, onError: reportError),
      ];
      controller.onCancel = () async {
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
      };
    });
  }

  @override
  Stream<RouletteSpin> watchSpins() async* {
    final pairId = await _pairId();
    if (pairId == null) return;
    final spins = client
        .from('pair_roulette_spins')
        .stream(primaryKey: ['pair_id'])
        .eq('pair_id', pairId);
    yield* spins
        .where((rows) => rows.isNotEmpty)
        .map(
          (rows) =>
              RouletteSpin.fromJson(Map<String, dynamic>.from(rows.first)),
        );
  }
}
