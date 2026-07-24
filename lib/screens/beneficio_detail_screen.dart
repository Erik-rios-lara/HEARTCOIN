import 'package:flutter/material.dart';

import '../services/beneficio_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/mini_map.dart';
import 'beneficio_scanner_screen.dart';

/// Detalle de un beneficio: descripción completa, condiciones,
/// ubicación en mapa y acceso al escáner para canjearlo.
class BeneficioDetailScreen extends StatefulWidget {
  final Map<String, dynamic> beneficio;
  const BeneficioDetailScreen({super.key, required this.beneficio});

  @override
  State<BeneficioDetailScreen> createState() => _BeneficioDetailScreenState();
}

class _BeneficioDetailScreenState extends State<BeneficioDetailScreen> {
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

  List<Map<String, dynamic>> _otherBeneficios = [];

  @override
  void initState() {
    super.initState();
    _loadOtherBeneficios();
  }

  Future<void> _loadOtherBeneficios() async {
    try {
      final beneficios = await BeneficioService.instance
          .fetchActiveBeneficios();
      if (!mounted) return;
      setState(
        () => _otherBeneficios = beneficios
            .where(
              (b) =>
                  b['id'] != widget.beneficio['id'] &&
                  b['latitude'] != null &&
                  b['longitude'] != null,
            )
            .toList(),
      );
    } catch (_) {
      // Sin otros beneficios cargados, el mapa simplemente muestra solo este.
    }
  }

  void _openOtherBeneficio(Map<String, dynamic> beneficio) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BeneficioDetailScreen(beneficio: beneficio),
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primarioBlanco,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Compartir'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final beneficio = widget.beneficio;
    final benefitType = beneficio['benefit_type'] as String? ?? 'otro';
    final title = beneficio['title'] as String? ?? 'Beneficio';
    final description = beneficio['description'] as String?;
    final terms = beneficio['terms'] as String?;
    final imageUrl = beneficio['image_url'] as String?;
    final hcCost = (beneficio['hc_cost'] as num?)?.toInt();
    final hcReward = (beneficio['hc_reward'] as num?)?.toInt();
    final isCashback = benefitType == 'cashback';
    final hcAmount = isCashback ? hcReward : hcCost;
    final maxRedemptions = (beneficio['max_redemptions'] as num?)?.toInt();
    final redemptionsCount =
        (beneficio['redemptions_count'] as num?)?.toInt() ?? 0;
    final expiresAt = DateTime.tryParse(
      beneficio['expires_at'] as String? ?? '',
    );
    final latitude = (beneficio['latitude'] as num?)?.toDouble();
    final longitude = (beneficio['longitude'] as num?)?.toDouble();
    final location = beneficio['location'] as String?;

    final conditions = <String>[
      if (terms != null && terms.trim().isNotEmpty)
        ...terms.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty),
      if (expiresAt != null)
        'Vigencia: hasta ${expiresAt.day.toString().padLeft(2, '0')}/${expiresAt.month.toString().padLeft(2, '0')}/${expiresAt.year}',
    ];

    return Scaffold(
      backgroundColor: AppColors.gris100,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(
              imageUrl: imageUrl,
              typeIcon: _typeIcons[benefitType] ?? Icons.card_giftcard,
              typeLabel: (_typeLabels[benefitType] ?? benefitType)
                  .toUpperCase(),
              title: title,
              hcAmount: hcAmount,
              redemptionsCount: redemptionsCount,
              maxRedemptions: maxRedemptions,
              onBack: () => Navigator.of(context).maybePop(),
              onMore: _showOptions,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarioNegro,
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

                  if (conditions.isNotEmpty) ...[
                    const _SectionLabel('Condiciones'),
                    _BulletList(items: conditions),
                    const SizedBox(height: 20),
                  ],

                  if (latitude != null && longitude != null) ...[
                    const _SectionLabel('Ubicaciones'),
                    MiniMap(
                      latitude: latitude,
                      longitude: longitude,
                      label: location,
                      otherLocations: _otherBeneficios,
                      onTapOtherLocation: _openOtherBeneficio,
                    ),
                    const SizedBox(height: 24),
                  ],

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
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        onTapHome: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onTapSearch: () => Navigator.of(context).pushNamed('/search'),
        onTapActions: () => Navigator.of(context).pushNamed('/mis-acciones'),
        onTapProfile: () => Navigator.of(context).pushNamed('/profile'),
      ),
    );
  }
}

/// Imagen de fondo (o degradado si no hay foto) con los botones de
/// regresar/más superpuestos, y la tarjeta de descuento que se
/// sobrepone al borde inferior.
class _Hero extends StatelessWidget {
  final String? imageUrl;
  final IconData typeIcon;
  final String typeLabel;
  final String title;
  final int? hcAmount;
  final int redemptionsCount;
  final int? maxRedemptions;
  final VoidCallback onBack;
  final VoidCallback onMore;

  const _Hero({
    required this.imageUrl,
    required this.typeIcon,
    required this.typeLabel,
    required this.title,
    required this.hcAmount,
    required this.redemptionsCount,
    required this.maxRedemptions,
    required this.onBack,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = maxRedemptions != null
        ? (maxRedemptions! - redemptionsCount).clamp(0, maxRedemptions!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: imageUrl != null
                    ? Image.network(imageUrl!, fit: BoxFit.cover)
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primarioRojo,
                              AppColors.rojoOscuro1,
                            ],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          typeIcon,
                          size: 72,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CircleIconButton(icon: Icons.arrow_back, onTap: onBack),
                    _CircleIconButton(icon: Icons.more_vert, onTap: onMore),
                  ],
                ),
              ),
            ),
          ],
        ),
        Transform.translate(
          offset: const Offset(0, -46),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primarioNegro.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (remaining != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Disponible: $remaining/$maxRedemptions',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hcAmount != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$hcAmount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
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

class _BulletList extends StatelessWidget {
  final List<String> items;
  const _BulletList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.gris600,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.gris700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
