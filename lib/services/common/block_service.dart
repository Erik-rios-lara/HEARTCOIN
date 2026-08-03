import 'package:supabase_flutter/supabase_flutter.dart';

class BlockService {
  BlockService._();
  static final BlockService instance = BlockService._();
  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// IDs de usuarios bloqueados por el usuario actual.
  Future<Set<String>> fetchBlockedIds() async {
    final userId = _userId;
    if (userId == null) return {};
    final rows = await _client
        .from('blocked_users')
        .select('blocked_user_id')
        .eq('user_id', userId);
    return rows.map((r) => r['blocked_user_id'] as String).toSet();
  }

  Future<List<Map<String, dynamic>>> fetchBlockedProfiles() async {
    final userId = _userId;
    if (userId == null) return [];
    final rows = await _client
        .from('blocked_users')
        .select('blocked_user_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final ids = rows.map((r) => r['blocked_user_id'] as String).toList();
    if (ids.isEmpty) return [];

    final profiles = await _client
        .from('personal_profiles')
        .select('id, full_name, avatar_url')
        .inFilter('id', ids);
    final byId = {for (final p in profiles) p['id']: p};

    return rows
        .map((r) => byId[r['blocked_user_id']])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> blockUser(String blockedUserId) async {
    final userId = _userId;
    if (userId == null) throw StateError('No hay sesión activa.');
    await _client.from('blocked_users').insert({
      'user_id': userId,
      'blocked_user_id': blockedUserId,
    });
  }

  Future<void> unblockUser(String blockedUserId) async {
    final userId = _userId;
    if (userId == null) return;
    await _client
        .from('blocked_users')
        .delete()
        .eq('user_id', userId)
        .eq('blocked_user_id', blockedUserId);
  }
}
