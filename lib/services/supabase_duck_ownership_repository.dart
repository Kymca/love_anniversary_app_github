import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pair_room.dart';
import 'duck_ownership_repository.dart';
import 'pair_repository.dart';
import 'participant_profile_repository.dart';

class SupabaseDuckOwnershipRepository implements DuckOwnershipService {
  SupabaseDuckOwnershipRepository({
    required this.client,
    required this.pairRepository,
    required this.profileRepository,
  });

  final SupabaseClient client;
  final PairRepository pairRepository;
  final ParticipantProfileRepository profileRepository;

  Future<PairRoom> _activePair() async =>
      await pairRepository.loadActivePair() ??
      (throw StateError('Join a pair to use the duck.'));

  @override
  Future<String> ownerFor(DateTime date) async {
    final pair = await _activePair();
    final response = await client.rpc(
      'get_daily_duck_owner',
      params: {'p_pair_id': pair.id},
    );
    if (response is! Map || response['owner'] is! String) {
      throw const FormatException('Backend returned an invalid duck owner.');
    }
    final owner = response['owner'] as String;
    if (owner != 'first' && owner != 'second') {
      throw const FormatException('Backend returned an invalid duck owner.');
    }
    return owner;
  }

  @override
  Future<bool> isCurrentParticipantOwner(DateTime date) async =>
      await profileRepository.loadCurrentSide() == await ownerFor(date);

  @override
  Future<String> requireCurrentOwner(DateTime date) async {
    final side = await profileRepository.loadCurrentSide();
    if (side != await ownerFor(date)) throw const DuckNotOwnedException();
    return side;
  }

  @override
  Future<void> requireParticipantSide(String side) async {
    if (side != await profileRepository.loadCurrentSide()) {
      throw const DuckNotOwnedException();
    }
  }
}
