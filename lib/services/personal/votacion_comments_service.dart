import 'package:supabase_flutter/supabase_flutter.dart';

class VotacionCommentsService {
  VotacionCommentsService._();
  static final VotacionCommentsService instance = VotacionCommentsService._();
  SupabaseClient get _client => Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> commentsStream(String votacionId) {
    return _client
        .from('votacion_comments')
        .stream(primaryKey: ['id'])
        .eq('votacion_id', votacionId)
        .order('created_at');
  }

  Future<void> addComment({
    required String votacionId,
    required String content,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No hay sesión activa.');

    final profile = await _client
        .from('personal_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    await _client.from('votacion_comments').insert({
      'votacion_id': votacionId,
      'author_id': userId,
      'author_name': profile?['full_name'] as String? ?? 'Usuario HeartCoin',
      'author_avatar_url': profile?['avatar_url'] as String?,
      'content': content,
    });
  }
}
