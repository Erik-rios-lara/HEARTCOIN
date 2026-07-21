import 'package:supabase_flutter/supabase_flutter.dart';

class RedeemServicioException implements Exception {
  final String message;
  RedeemServicioException(this.message);

  @override
  String toString() => message;
}

class ServicioService {
  ServicioService._();
  static final ServicioService instance = ServicioService._();
  SupabaseClient get _client => Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> myServiciosStream() {
    return _client.from('servicios').stream(primaryKey: ['id']);
  }

  Future<List<Map<String, dynamic>>> fetchActiveServicios({
    String? category,
    String? search,
  }) async {
    var query = _client.from('servicios').select().eq('status', 'activo');
    if (category != null) {
      query = query.eq('category', category);
    }
    if (search != null && search.isNotEmpty) {
      query = query.ilike('title', '%$search%');
    }
    final rows = await query.order('created_at', ascending: false);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> fetchServicio(String servicioId) {
    return _client
        .from('servicios')
        .select()
        .eq('id', servicioId)
        .maybeSingle();
  }

  Future<void> createServicio({
    required String title,
    required String description,
    String? category,
    required String pricingType,
    int? hcCost,
    int? hcReward,
    int? maxRedemptions,
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No hay sesión activa.');

    await _client.from('servicios').insert({
      'company_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'pricing_type': pricingType,
      'hc_cost': hcCost,
      'hc_reward': hcReward,
      'max_redemptions': maxRedemptions,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<void> setStatus(String servicioId, String status) async {
    await _client
        .from('servicios')
        .update({'status': status})
        .eq('id', servicioId);
  }

  Future<bool> hasRedeemed(String servicioId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('servicio_redemptions')
        .select('servicio_id')
        .eq('servicio_id', servicioId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<void> redeem(String servicioId) async {
    try {
      await _client.rpc(
        'redeem_servicio',
        params: {'p_servicio_id': servicioId},
      );
    } on PostgrestException catch (e) {
      throw RedeemServicioException(_mapError(e.message));
    }
  }

  String _mapError(String raw) {
    if (raw.contains('ya_canjeado')) {
      return 'Ya canjeaste este servicio.';
    }
    if (raw.contains('limite_alcanzado')) {
      return 'Este servicio ya alcanzó su límite de canjes.';
    }
    if (raw.contains('servicio_inactivo')) {
      return 'Este servicio ya no está activo.';
    }
    if (raw.contains('hc_insuficiente')) {
      return 'No tienes suficientes HC para canjear este servicio.';
    }
    if (raw.contains('servicio_no_encontrado')) {
      return 'No se encontró el servicio.';
    }
    return 'No se pudo completar el canje. Intenta de nuevo.';
  }
}
