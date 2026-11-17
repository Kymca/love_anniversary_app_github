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
    final rows = await client.rpc(
      'get_pair_roulette_exclusions',
      params: {'p_pair_id': id, 'p_category': category.name},
    );
    if (rows is! List) {
      throw const FormatException(
        'Backend returned invalid roulette exclusions.',
      );
    }
    return List.unmodifiable(
      rows.map((row) {
        if (row is! Map || row['choice_key'] is! String) {
          throw const FormatException(
            'Backend returned an invalid roulette exclusion.',
          );
        }
        return row['choice_key'] as String;
      }),
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
}
