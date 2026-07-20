import 'package:supabase_flutter/supabase_flutter.dart';

/// Un certificado se genera a partir de cada check-in confirmado
/// (proof of participation) en una iniciativa de Voluntariado/Social.
class CertificadoService {
  CertificadoService._();
  static final CertificadoService instance = CertificadoService._();
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchMyCertificados() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _client
        .from('iniciativa_checkins')
        .select(
          'created_at, iniciativas(id, title, category, organization_name, event_date)',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows.cast<Map<String, dynamic>>();
  }
}
