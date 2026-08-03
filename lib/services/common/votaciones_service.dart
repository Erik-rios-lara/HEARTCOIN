import 'package:supabase_flutter/supabase_flutter.dart';

class AlreadyVotedException implements Exception {
  @override
  String toString() => 'Ya votaste por esta iniciativa.';
}

class VotacionesService {
  VotacionesService._();
  static final VotacionesService instance = VotacionesService._();

  SupabaseClient get _client => Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> votacionesStream() {
    return _client.from('votaciones').stream(primaryKey: ['id']);
  }

  Future<bool> hasVoted(String votacionId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('votacion_votes')
        .select('votacion_id')
        .eq('votacion_id', votacionId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<void> vote(String votacionId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No hay sesión activa.');
    try {
      await _client.from('votacion_votes').insert({
        'votacion_id': votacionId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw AlreadyVotedException();
      }
      rethrow;
    }
  }
}
