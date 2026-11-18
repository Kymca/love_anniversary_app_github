import 'duck_name_repository.dart';
import 'duck_ownership_repository.dart';
import 'pair_repository.dart';
import 'roulette_repository.dart';
import 'supabase_backend.dart';
import '../models/pair_room.dart';

class UnavailablePairRepository implements PairRepository {
  UnavailablePairRepository(this.reason);

  final Object reason;

  @override
  Future<PairRoom> createPair(String name) =>
      Future.error(SupabaseUnavailableException(reason));

  @override
  Future<PairRoom> joinPair(String name, String code) =>
      Future.error(SupabaseUnavailableException(reason));

  @override
  Future<PairRoom?> loadActivePair() async => null;

  @override
  Future<void> deletePair(PairRoom room) =>
      Future.error(SupabaseUnavailableException(reason));
}

class UnavailableDuckNameRepository implements DuckNameRepository {
  UnavailableDuckNameRepository(this.reason);

  final String reason;

  Never _unavailable() => throw SupabaseUnavailableException(reason);

  @override
  bool get isSynchronized => false;

  @override
  Future<String?> loadName(String? pairId) async => _unavailable();

  @override
  Future<bool> claimNamingPrompt(String? pairId) async => _unavailable();

  @override
  Future<String> saveName(String? pairId, String name) async => _unavailable();

  @override
  Stream<String?> watchName(String? pairId) =>
      Stream.error(SupabaseUnavailableException(reason));
}

class UnavailableDuckOwnershipRepository implements DuckOwnershipService {
  UnavailableDuckOwnershipRepository(this.reason);

  final String reason;
  Never _unavailable() => throw SupabaseUnavailableException(reason);

  @override
  Future<String> ownerFor(DateTime date) async => _unavailable();

  @override
  Future<bool> isCurrentParticipantOwner(DateTime date) async => _unavailable();

  @override
  Future<String> requireCurrentOwner(DateTime date) async => _unavailable();

  @override
  Future<void> requireParticipantSide(String side) async => _unavailable();
}

class UnavailableRouletteRepository implements RouletteRepository {
  UnavailableRouletteRepository(this.reason);

  final String reason;
  Never _unavailable() => throw SupabaseUnavailableException(reason);

  @override
  Future<List<String>> loadSharedChoices(RouletteCategory category) async =>
      _unavailable();

  @override
  Future<List<String>> loadCustomChoices(RouletteCategory category) async =>
      _unavailable();

  @override
  Future<List<String>> loadExcludedChoiceKeys(
    RouletteCategory category,
  ) async => _unavailable();

  @override
  Future<void> addChoice(RouletteCategory category, String choice) async =>
      _unavailable();

  @override
  Future<void> removeChoice(RouletteCategory category, String choice) async =>
      _unavailable();

  @override
  Future<void> applyChoice(
    RouletteCategory category,
    String choice,
    String choiceKey,
  ) async => _unavailable();

  @override
  Stream<void> watchChanges(RouletteCategory category) =>
      Stream.error(SupabaseUnavailableException(reason));

  @override
  Future<RouletteSpin?> startSpin(
    RouletteCategory category,
    String choice,
    String choiceKey,
  ) async => _unavailable();

  @override
  Stream<RouletteSpin> watchSpins() =>
      Stream.error(SupabaseUnavailableException(reason));
}
