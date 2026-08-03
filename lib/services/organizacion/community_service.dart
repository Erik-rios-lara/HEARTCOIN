import 'package:supabase_flutter/supabase_flutter.dart';

/// Usuarios que han participado votando en votaciones o apoyando
/// iniciativas, con su conteo total de participaciones.
class CommunityService {
  CommunityService._();
  static final CommunityService instance = CommunityService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> loadParticipants() async {
    final votacionVotes = await _client
        .from('votacion_votes')
        .select('user_id');
    final iniciativaVotes = await _client
        .from('iniciativa_votes')
        .select('user_id');

    final counts = <String, int>{};
    for (final row in [...votacionVotes, ...iniciativaVotes]) {
      final userId = row['user_id'] as String;
      counts[userId] = (counts[userId] ?? 0) + 1;
    }
    if (counts.isEmpty) return [];

    final profiles = await _client
        .from('personal_profiles')
        .select()
        .inFilter('id', counts.keys.toList());

    final participants = (profiles as List)
        .cast<Map<String, dynamic>>()
        .map(
          (profile) => {
            ...profile,
            'participation_count': counts[profile['id']] ?? 0,
          },
        )
        .toList();

    participants.sort(
      (a, b) => (b['participation_count'] as int).compareTo(
        a['participation_count'] as int,
      ),
    );
    return participants;
  }
}
