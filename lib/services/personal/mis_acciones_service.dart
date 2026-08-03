import 'package:supabase_flutter/supabase_flutter.dart';

class AccionesStats {
  final int hcBalance;
  final int totalVotos;
  final int totalCheckins;

  const AccionesStats({
    required this.hcBalance,
    required this.totalVotos,
    required this.totalCheckins,
  });

  static const empty = AccionesStats(
    hcBalance: 0,
    totalVotos: 0,
    totalCheckins: 0,
  );
}

/// Historial de participación del usuario: apoyos, votos, check-ins
/// y canjes, combinados en una sola lista ordenada por fecha.
class MisAccionesService {
  MisAccionesService._();
  static final MisAccionesService instance = MisAccionesService._();
  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<AccionesStats> fetchStats() async {
    final userId = _userId;
    if (userId == null) return AccionesStats.empty;

    final profile = await _client
        .from('personal_profiles')
        .select('hc_balance')
        .eq('id', userId)
        .maybeSingle();

    final votosIniciativas = await _client
        .from('iniciativa_votes')
        .select('iniciativa_id')
        .eq('user_id', userId)
        .count();
    final votosVotaciones = await _client
        .from('votacion_votes')
        .select('votacion_id')
        .eq('user_id', userId)
        .count();
    final checkins = await _client
        .from('iniciativa_checkins')
        .select('iniciativa_id')
        .eq('user_id', userId)
        .count();

    return AccionesStats(
      hcBalance: (profile?['hc_balance'] as num?)?.toInt() ?? 0,
      totalVotos: votosIniciativas.count + votosVotaciones.count,
      totalCheckins: checkins.count,
    );
  }

  Future<List<Map<String, dynamic>>> fetchAcciones() async {
    final userId = _userId;
    if (userId == null) return [];

    final apoyos = await _client
        .from('iniciativa_votes')
        .select(
          'created_at, iniciativas(id, title, category, organization_name)',
        )
        .eq('user_id', userId);

    final votos = await _client
        .from('votacion_votes')
        .select(
          'created_at, votaciones(id, title, type, foundation_name, hc_reward)',
        )
        .eq('user_id', userId);

    final checkins = await _client
        .from('iniciativa_checkins')
        .select(
          'created_at, iniciativas(id, title, category, organization_name, hc_reward)',
        )
        .eq('user_id', userId);

    final canjes = await _client
        .from('beneficio_redemptions')
        .select(
          'created_at, beneficios(id, title, benefit_type, company_name, hc_cost, hc_reward)',
        )
        .eq('user_id', userId);

    final acciones = <Map<String, dynamic>>[];

    for (final row in apoyos) {
      final iniciativa = row['iniciativas'] as Map<String, dynamic>?;
      if (iniciativa == null) continue;
      acciones.add({
        'action_type': 'apoyo',
        'title': iniciativa['title'],
        'subtitle': iniciativa['organization_name'],
        'created_at': row['created_at'],
        'hc_delta': 0,
      });
    }

    for (final row in votos) {
      final votacion = row['votaciones'] as Map<String, dynamic>?;
      if (votacion == null) continue;
      acciones.add({
        'action_type': 'voto',
        'title': votacion['title'],
        'subtitle': votacion['foundation_name'],
        'created_at': row['created_at'],
        'hc_delta': (votacion['hc_reward'] as num?)?.toInt() ?? 0,
      });
    }

    for (final row in checkins) {
      final iniciativa = row['iniciativas'] as Map<String, dynamic>?;
      if (iniciativa == null) continue;
      acciones.add({
        'action_type': 'checkin',
        'title': iniciativa['title'],
        'subtitle': iniciativa['organization_name'],
        'created_at': row['created_at'],
        'hc_delta': (iniciativa['hc_reward'] as num?)?.toInt() ?? 0,
      });
    }

    for (final row in canjes) {
      final beneficio = row['beneficios'] as Map<String, dynamic>?;
      if (beneficio == null) continue;
      final isCashback = beneficio['benefit_type'] == 'cashback';
      final hcDelta = isCashback
          ? (beneficio['hc_reward'] as num?)?.toInt() ?? 0
          : -((beneficio['hc_cost'] as num?)?.toInt() ?? 0);
      acciones.add({
        'action_type': 'canje',
        'title': beneficio['title'],
        'subtitle': beneficio['company_name'],
        'created_at': row['created_at'],
        'hc_delta': hcDelta,
      });
    }

    acciones.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at'] as String? ?? '');
      final dateB = DateTime.tryParse(b['created_at'] as String? ?? '');
      if (dateA == null || dateB == null) return 0;
      return dateB.compareTo(dateA);
    });

    return acciones;
  }
}
