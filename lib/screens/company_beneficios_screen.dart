import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/beneficio_service.dart';
import '../theme/app_colors.dart';
import 'beneficio_detail_screen.dart';
import 'beneficio_qr_screen.dart';
import 'create_beneficio_screen.dart';

/// Beneficios publicados por la empresa (descuentos, cashback,
/// becas), con su código QR de canje.
class CompanyBeneficiosScreen extends StatefulWidget {
  const CompanyBeneficiosScreen({super.key});

  @override
  State<CompanyBeneficiosScreen> createState() =>
      _CompanyBeneficiosScreenState();
}

class _CompanyBeneficiosScreenState extends State<CompanyBeneficiosScreen> {
  final _client = Supabase.instance.client;

  List<Map<String, dynamic>> _ownBeneficios(List<Map<String, dynamic>> all) {
    final userId = _client.auth.currentUser?.id;
    return all.where((b) => b['company_id'] == userId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Mis beneficios'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateBeneficioScreen()),
          );
          if (created == true && mounted) setState(() {});
        },
        backgroundColor: AppColors.primarioRojo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: BeneficioService.instance.myBeneficiosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            );
          }

          final own = _ownBeneficios(snapshot.data ?? []);

          if (own.isEmpty) {
            return Center(
              child: Text(
                'Aún no has publicado beneficios.',
                style: TextStyle(color: AppColors.gris600),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: own
                .map(
                  (beneficio) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BeneficioCard(beneficio: beneficio),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _BeneficioCard extends StatelessWidget {
  final Map<String, dynamic> beneficio;
  const _BeneficioCard({required this.beneficio});

  static const _typeLabels = {
    'descuento': 'Descuento',
    'cashback': 'Cashback',
    'beca': 'Beca',
    'otro': 'Otro',
  };

  static const _typeIcons = {
    'descuento': Icons.percent,
    'cashback': Icons.replay_circle_filled,
    'beca': Icons.school_outlined,
    'otro': Icons.card_giftcard,
  };

  @override
  Widget build(BuildContext context) {
    final id = beneficio['id'] as String?;
    final title = beneficio['title'] as String? ?? 'Beneficio';
    final benefitType = beneficio['benefit_type'] as String? ?? 'otro';
    final status = beneficio['status'] as String? ?? 'activo';
    final isActive = status == 'activo';
    final hcCost = (beneficio['hc_cost'] as num?)?.toInt();
    final hcReward = (beneficio['hc_reward'] as num?)?.toInt();
    final redemptionsCount =
        (beneficio['redemptions_count'] as num?)?.toInt() ?? 0;
    final maxRedemptions = (beneficio['max_redemptions'] as num?)?.toInt();

    final hcLabel = benefitType == 'cashback'
        ? '+$hcReward HC por canje'
        : '$hcCost HC por canje';

    return Material(
      color: AppColors.primarioBlanco,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BeneficioDetailScreen(beneficio: beneficio),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _typeIcons[benefitType] ?? Icons.card_giftcard,
                    color: AppColors.primarioRojo,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _typeLabels[benefitType] ?? benefitType,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarioRojo,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isActive
                                  ? AppColors.secundarioVerde
                                  : AppColors.gris600)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isActive ? 'Activo' : 'Inactivo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? AppColors.secundarioVerde
                            : AppColors.gris600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarioNegro,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hcLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gris700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                maxRedemptions != null
                    ? '$redemptionsCount / $maxRedemptions canjes'
                    : '$redemptionsCount canjes',
                style: TextStyle(fontSize: 12, color: AppColors.gris600),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await BeneficioService.instance.setStatus(
                          id!,
                          isActive ? 'inactivo' : 'activo',
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gris700,
                        side: BorderSide(color: AppColors.gris300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(isActive ? 'Desactivar' : 'Activar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: id == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BeneficioQrScreen(
                                  beneficioId: id,
                                  beneficioTitle: title,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.qr_code, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primarioRojo,
                        side: const BorderSide(color: AppColors.primarioRojo),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: const Text('QR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
