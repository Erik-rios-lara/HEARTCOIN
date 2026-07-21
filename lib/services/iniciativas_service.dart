import 'package:supabase_flutter/supabase_flutter.dart';

class AlreadyVotedIniciativaException implements Exception {
  @override
  String toString() => 'Ya apoyaste esta iniciativa.';
}

class IniciativasService {
  IniciativasService._();
  static final IniciativasService instance = IniciativasService._();

  SupabaseClient get _client => Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> iniciativasStream() {
    return _client.from('iniciativas').stream(primaryKey: ['id']);
  }

  Future<bool> hasVoted(String iniciativaId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('iniciativa_votes')
        .select('iniciativa_id')
        .eq('iniciativa_id', iniciativaId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<void> vote(String iniciativaId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No hay sesión activa.');
    try {
      await _client.from('iniciativa_votes').insert({
        'iniciativa_id': iniciativaId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw AlreadyVotedIniciativaException();
      }
      rethrow;
    }
  }

  Future<void> updateCurrentAmount(String iniciativaId, double amount) async {
    await _client
        .from('iniciativas')
        .update({'current_amount': amount})
        .eq('id', iniciativaId);
  }
}
