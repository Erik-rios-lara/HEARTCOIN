import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'beneficio_scanner_screen.dart';

/// Detalle de un beneficio: descripción completa, términos,
/// vigencia y acceso al escáner para canjearlo.
class BeneficioDetailScreen extends StatelessWidget {
  final Map<String, dynamic> beneficio;
  const BeneficioDetailScreen({super.key, required this.beneficio});

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
    final benefitType = beneficio['benefit_type'] as String? ?? 'otro';
    final title = beneficio['title'] as String? ?? 'Beneficio';
    final companyName = beneficio['company_name'] as String?;
    final description = beneficio['description'] as String?;
    final terms = beneficio['terms'] as String?;
    final hcCost = (beneficio['hc_cost'] as num?)?.toInt();
    final hcReward = (beneficio['hc_reward'] as num?)?.toInt();
    final isCashback = benefitType == 'cashback';
    final hcLabel = isCashback ? '+$hcReward HC' : '$hcCost HC';
    final maxRedemptions = (beneficio['max_redemptions'] as num?)?.toInt();
    final redemptionsCount =
        (beneficio['redemptions_count'] as num?)?.toInt() ?? 0;
    final expiresAt = DateTime.tryParse(
      beneficio['expires_at'] as String? ?? '',
    );

    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Detalle del beneficio'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primarioRojo, AppColors.rojoOscuro1],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _typeIcons[benefitType] ?? Icons.card_giftcard,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _typeLabels[benefitType] ?? benefitType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (companyName != null && companyName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.apartment,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        companyName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCashback ? 'Recibes $hcLabel' : 'Cuesta $hcLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (description != null && description.isNotEmpty) ...[
            const _SectionLabel('Descripción'),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.gris800,
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (terms != null && terms.isNotEmpty) ...[
            const _SectionLabel('Términos y condiciones'),
            Text(
              terms,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.gris700,
              ),
            ),
            const SizedBox(height: 20),
          ],

          const _SectionLabel('Disponibilidad'),
          _InfoRow(
            icon: Icons.qr_code_scanner,
            label: maxRedemptions != null
                ? '$redemptionsCount / $maxRedemptions canjes realizados'
                : '$redemptionsCount canjes realizados',
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.event_busy,
              label:
                  'Vence el ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
            ),
          ],
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BeneficioScannerScreen(),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarioRojo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: const Text(
                'Escanear para canjear',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primarioNegro,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gris600),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.gris700)),
      ],
    );
  }
}
