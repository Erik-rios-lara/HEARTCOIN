import 'package:supabase_flutter/supabase_flutter.dart';

/// Ranking de usuarios por número de check-ins confirmados en
/// iniciativas (Voluntariado/Social), como medida de participación
/// real (no de gasto/ahorro de HC).
class RankingService {
  RankingService._();
  static final RankingService instance = RankingService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchTopByCheckins() async {
    final checkins = await _client
        .from('iniciativa_checkins')
        .select('user_id');

    final counts = <String, int>{};
    for (final row in checkins) {
      final userId = row['user_id'] as String;
      counts[userId] = (counts[userId] ?? 0) + 1;
    }
    if (counts.isEmpty) return [];

    final profiles = await _client
        .from('personal_profiles')
        .select()
        .inFilter('id', counts.keys.toList());

    final ranking = (profiles as List)
        .cast<Map<String, dynamic>>()
        .map(
          (profile) => {
            ...profile,
            'checkin_count': counts[profile['id']] ?? 0,
          },
        )
        .toList();

    ranking.sort(
      (a, b) =>
          (b['checkin_count'] as int).compareTo(a['checkin_count'] as int),
    );
    return ranking;
  }
}
