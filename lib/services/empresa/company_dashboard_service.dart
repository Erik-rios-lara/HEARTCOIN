import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyDashboardStats {
  final int activeCount;
  final int expiringSoonCount;
  final int totalRedemptions;
  final int hcAwardedCashback;
  final int hcCollectedSpend;

  const CompanyDashboardStats({
    required this.activeCount,
    required this.expiringSoonCount,
    required this.totalRedemptions,
    required this.hcAwardedCashback,
    required this.hcCollectedSpend,
  });

  static const empty = CompanyDashboardStats(
    activeCount: 0,
    expiringSoonCount: 0,
    totalRedemptions: 0,
    hcAwardedCashback: 0,
    hcCollectedSpend: 0,
  );
}

class CompanyDashboardService {
  CompanyDashboardService._();
  static final CompanyDashboardService instance = CompanyDashboardService._();
  SupabaseClient get _client => Supabase.instance.client;

  Future<CompanyDashboardStats> fetchStats(String companyId) async {
    final beneficios = await _client
        .from('beneficios')
        .select('id, status, expires_at, redemptions_count')
        .eq('company_id', companyId);

    final ids = beneficios.map((b) => b['id'] as String).toList();
    final activeCount = beneficios.where((b) => b['status'] == 'activo').length;

    final now = DateTime.now();
    final soon = now.add(const Duration(days: 7));
    final expiringSoonCount = beneficios.where((b) {
      if (b['status'] != 'activo') return false;
      final expiresAt = DateTime.tryParse(b['expires_at'] as String? ?? '');
      if (expiresAt == null) return false;
      return expiresAt.isAfter(now) && expiresAt.isBefore(soon);
    }).length;

    final totalRedemptions = beneficios.fold<int>(
      0,
      (sum, b) => sum + ((b['redemptions_count'] as num?)?.toInt() ?? 0),
    );

    if (ids.isEmpty) {
      return CompanyDashboardStats(
        activeCount: activeCount,
        expiringSoonCount: expiringSoonCount,
        totalRedemptions: totalRedemptions,
        hcAwardedCashback: 0,
        hcCollectedSpend: 0,
      );
    }

    final transactions = await _client
        .from('hc_transactions')
        .select('amount, type, reference_id')
        .inFilter('reference_type', ['beneficio'])
        .inFilter('reference_id', ids);

    var hcAwardedCashback = 0;
    var hcCollectedSpend = 0;
    for (final t in transactions) {
      final amount = (t['amount'] as num?)?.toInt() ?? 0;
      final type = t['type'] as String?;
      if (type == 'redemption_cashback') {
        hcAwardedCashback += amount;
      } else if (type == 'redemption_spend') {
        hcCollectedSpend += -amount;
      }
    }

    return CompanyDashboardStats(
      activeCount: activeCount,
      expiringSoonCount: expiringSoonCount,
      totalRedemptions: totalRedemptions,
      hcAwardedCashback: hcAwardedCashback,
      hcCollectedSpend: hcCollectedSpend,
    );
  }
}
