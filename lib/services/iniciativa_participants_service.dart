import 'package:supabase_flutter/supabase_flutter.dart';

/// Participantes reales, invitaciones y solicitudes de unión para
/// iniciativas de Ahorro. Ver SQL/migrations/001_iniciativa_participantes.sql.
class IniciativaParticipantsService {
  IniciativaParticipantsService._();
  static final IniciativaParticipantsService instance =
      IniciativaParticipantsService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Titular (autor de la iniciativa) primero, luego los participantes
  /// invitados, cada uno con su perfil (`full_name`, `avatar_url`).
  Future<List<Map<String, dynamic>>> fetchParticipants(
    String iniciativaId,
  ) async {
    final iniciativa = await _client
        .from('iniciativas')
        .select('author_id')
        .eq('id', iniciativaId)
        .single();
    final authorId = iniciativa['author_id'] as String?;

    final result = <Map<String, dynamic>>[];

    if (authorId != null) {
      final authorProfile = await _client
          .from('personal_profiles')
          .select('full_name, avatar_url')
          .eq('id', authorId)
          .maybeSingle();
      result.add({
        'user_id': authorId,
        'full_name': authorProfile?['full_name'] ?? 'Titular',
        'avatar_url': authorProfile?['avatar_url'],
        'role': 'titular',
      });
    }

    final participantRows = await _client
        .from('iniciativa_participants')
        .select('user_id')
        .eq('iniciativa_id', iniciativaId);
    final participantIds = (participantRows as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['user_id'] as String)
        .toList();

    if (participantIds.isNotEmpty) {
      final profiles = await _client
          .from('personal_profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', participantIds);
      final profileById = {
        for (final profile in (profiles as List).cast<Map<String, dynamic>>())
          profile['id'] as String: profile,
      };
      for (final userId in participantIds) {
        final profile = profileById[userId];
        result.add({
          'user_id': userId,
          'full_name': profile?['full_name'] ?? 'Participante',
          'avatar_url': profile?['avatar_url'],
          'role': 'participante',
        });
      }
    }

    return result;
  }

  Future<void> inviteParticipant({
    required String iniciativaId,
    required String userId,
  }) async {
    await _client.from('iniciativa_participants').insert({
      'iniciativa_id': iniciativaId,
      'user_id': userId,
    });
  }

  Future<void> requestToJoin(String iniciativaId) async {
    final userId = _userId;
    if (userId == null) throw StateError('No hay sesión activa.');
    await _client.from('iniciativa_join_requests').insert({
      'iniciativa_id': iniciativaId,
      'user_id': userId,
    });
  }

  /// `null` si nunca se ha solicitado, si no: 'pending' | 'accepted' | 'rejected'.
  Future<String?> myRequestStatus(String iniciativaId) async {
    final userId = _userId;
    if (userId == null) return null;
    final row = await _client
        .from('iniciativa_join_requests')
        .select('status')
        .eq('iniciativa_id', iniciativaId)
        .eq('user_id', userId)
        .maybeSingle();
    return row?['status'] as String?;
  }

  /// Solo trae resultados útiles si quien llama es el dueño de la iniciativa
  /// (aplicado por RLS). Cada fila incluye `full_name`/`avatar_url` del
  /// solicitante.
  Future<List<Map<String, dynamic>>> fetchPendingRequests(
    String iniciativaId,
  ) async {
    final rows = await _client
        .from('iniciativa_join_requests')
        .select('id, user_id')
        .eq('iniciativa_id', iniciativaId)
        .eq('status', 'pending');
    final requests = (rows as List).cast<Map<String, dynamic>>();
    if (requests.isEmpty) return [];

    final userIds = requests.map((r) => r['user_id'] as String).toList();
    final profiles = await _client
        .from('personal_profiles')
        .select('id, full_name, avatar_url')
        .inFilter('id', userIds);
    final profileById = {
      for (final profile in (profiles as List).cast<Map<String, dynamic>>())
        profile['id'] as String: profile,
    };

    return requests
        .map(
          (request) => {
            'id': request['id'],
            'user_id': request['user_id'],
            'full_name': profileById[request['user_id']]?['full_name'],
            'avatar_url': profileById[request['user_id']]?['avatar_url'],
          },
        )
        .toList();
  }

  Future<void> acceptRequest(String requestId) async {
    await _client.rpc(
      'accept_iniciativa_join_request',
      params: {'request_id': requestId},
    );
  }

  Future<void> rejectRequest(String requestId) async {
    await _client
        .from('iniciativa_join_requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);
  }
}
