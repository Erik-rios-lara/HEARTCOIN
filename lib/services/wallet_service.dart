import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();
  SupabaseClient get _client => Supabase.instance.client;

  /// Emite el perfil personal (incluyendo hc_balance) en tiempo real.
  Stream<Map<String, dynamic>?> profileStream() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return Stream.value(null);
    return _client
        .from('personal_profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Stream<List<Map<String, dynamic>>> transactionsStream() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return Stream.value(const []);
    return _client
        .from('hc_transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> activeBeneficiosStream() {
    return _client.from('beneficios').stream(primaryKey: ['id']);
  }
}
