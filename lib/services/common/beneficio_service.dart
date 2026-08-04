import 'package:supabase_flutter/supabase_flutter.dart';

class RedeemBeneficioException implements Exception {
  final String message;
  RedeemBeneficioException(this.message);

  @override
  String toString() => message;
}

class BeneficioService {
  BeneficioService._();
  static final BeneficioService instance = BeneficioService._();
  SupabaseClient get _client => Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> myBeneficiosStream() {
    return _client.from('beneficios').stream(primaryKey: ['id']);
  }

  Future<Map<String, dynamic>?> fetchBeneficio(String beneficioId) {
    return _client
        .from('beneficios')
        .select()
        .eq('id', beneficioId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchActiveBeneficios() async {
    final rows = await _client
        .from('beneficios')
        .select()
        .eq('status', 'activo');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> createBeneficio({
    required String title,
    required String description,
    required String benefitType,
    int? hcCost,
    int? hcReward,
    String? terms,
    int? maxRedemptions,
    DateTime? expiresAt,
    String? location,
    double? latitude,
    double? longitude,
    bool destacado = false,
    String? imageUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No hay sesión activa.');

    await _client.from('beneficios').insert({
      'company_id': userId,
      'title': title,
      'description': description,
      'benefit_type': benefitType,
      'hc_cost': hcCost,
      'hc_reward': hcReward,
      'terms': terms,
      'max_redemptions': maxRedemptions,
      'expires_at': expiresAt?.toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'destacado': destacado,
      'image_url': imageUrl,
    });
  }

  Future<void> setStatus(String beneficioId, String status) async {
    await _client
        .from('beneficios')
        .update({'status': status})
        .eq('id', beneficioId);
  }

  Future<bool> hasRedeemed(String beneficioId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('beneficio_redemptions')
        .select('beneficio_id')
        .eq('beneficio_id', beneficioId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<void> redeem(String beneficioId) async {
    try {
      await _client.rpc(
        'redeem_beneficio',
        params: {'p_beneficio_id': beneficioId},
      );
    } on PostgrestException catch (e) {
      throw RedeemBeneficioException(_mapError(e.message));
    }
  }

  String _mapError(String raw) {
    if (raw.contains('ya_canjeado')) {
      return 'Ya canjeaste este beneficio.';
    }
    if (raw.contains('limite_alcanzado')) {
      return 'Este beneficio ya alcanzó su límite de canjes.';
    }
    if (raw.contains('beneficio_inactivo')) {
      return 'Este beneficio ya no está activo.';
    }
    if (raw.contains('hc_insuficiente')) {
      return 'No tienes suficientes HC para canjear este beneficio.';
    }
    if (raw.contains('beneficio_no_encontrado')) {
      return 'No se encontró el beneficio.';
    }
    return 'No se pudo completar el canje. Intenta de nuevo.';
  }
}
