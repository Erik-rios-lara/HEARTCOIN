import 'package:supabase_flutter/supabase_flutter.dart';

class OrgDashboardStats {
  final int activeCount;
  final int votesTotal;
  final List<int> weeklyVotes;
  final int reachedPeople;

  const OrgDashboardStats({
    required this.activeCount,
    required this.votesTotal,
    required this.weeklyVotes,
    required this.reachedPeople,
  });

  static const empty = OrgDashboardStats(
    activeCount: 0,
    votesTotal: 0,
    weeklyVotes: [0, 0, 0, 0, 0, 0, 0],
    reachedPeople: 0,
  );
}

class OrgDashboardService {
  OrgDashboardService._();
  static final OrgDashboardService instance = OrgDashboardService._();
  SupabaseClient get _client => Supabase.instance.client;

  Future<OrgDashboardStats> fetchStats(String orgId) async {
    final iniciativas = await _client
        .from('iniciativas')
        .select('id, status')
        .eq('author_id', orgId);

    final ids = iniciativas.map((i) => i['id'] as String).toList();
    final activeCount = iniciativas
        .where((i) => i['status'] == 'activa')
        .length;

    if (ids.isEmpty) return OrgDashboardStats.empty;

    final votes = await _client
        .from('iniciativa_votes')
        .select('created_at')
        .inFilter('iniciativa_id', ids);

    final checkins = await _client
        .from('iniciativa_checkins')
        .select('user_id')
        .inFilter('iniciativa_id', ids);

    final reachedPeople = checkins
        .map((c) => c['user_id'] as String)
        .toSet()
        .length;

    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final weeklyVotes = List<int>.filled(7, 0);
    for (final vote in votes) {
      final createdAt = DateTime.tryParse(vote['created_at'] as String? ?? '');
      if (createdAt == null) continue;
      final local = createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final diff = day.difference(startOfWeek).inDays;
      if (diff >= 0 && diff < 7) weeklyVotes[diff]++;
    }

    return OrgDashboardStats(
      activeCount: activeCount,
      votesTotal: votes.length,
      weeklyVotes: weeklyVotes,
      reachedPeople: reachedPeople,
    );
  }
}
