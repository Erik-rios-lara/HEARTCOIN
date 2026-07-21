import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/servicio_service.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_map.dart';
import 'beneficio_scanner_screen.dart';
import 'servicio_qr_screen.dart';

/// Detalle de un servicio publicado por una empresa. Visible tanto
/// para el rol Personal (puede canjearlo con HC) como para la
/// empresa dueña (puede activar/desactivar y mostrar su QR).
class ServicioDetailScreen extends StatefulWidget {
  final Map<String, dynamic> servicio;
  const ServicioDetailScreen({super.key, required this.servicio});

  @override
  State<ServicioDetailScreen> createState() => _ServicioDetailScreenState();
}

class _ServicioDetailScreenState extends State<ServicioDetailScreen> {
  late Map<String, dynamic> _servicio;
  bool _isUpdating = false;
  bool? _hasRedeemed;
  List<Map<String, dynamic>> _otherServicios = [];

  @override
  void initState() {
    super.initState();
    _servicio = widget.servicio;
    if (!_isOwner) _loadRedeemedState();
    _loadOtherServicios();
  }

  Future<void> _loadOtherServicios() async {
    try {
      final servicios = await ServicioService.instance.fetchActiveServicios();
      if (!mounted) return;
      setState(
        () => _otherServicios = servicios
            .where(
              (s) =>
                  s['id'] != _servicio['id'] &&
                  s['latitude'] != null &&
                  s['longitude'] != null,
            )
            .toList(),
      );
    } catch (_) {
      // Sin otros servicios cargados, el mapa simplemente muestra solo este.
    }
  }

  void _openOtherServicio(Map<String, dynamic> servicio) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ServicioDetailScreen(servicio: servicio),
      ),
    );
  }

  bool get _isOwner {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return userId != null && userId == _servicio['company_id'];
  }

  Future<void> _loadRedeemedState() async {
    final id = _servicio['id'] as String?;
    if (id == null) return;
    final redeemed = await ServicioService.instance.hasRedeemed(id);
    if (mounted) setState(() => _hasRedeemed = redeemed);
  }

  Future<void> _toggleStatus() async {
    if (_isUpdating) return;
    final id = _servicio['id'] as String?;
    if (id == null) return;

    final isActive = (_servicio['status'] as String? ?? 'activo') == 'activo';
    final newStatus = isActive ? 'inactivo' : 'activo';

    setState(() => _isUpdating = true);
    try {
      await ServicioService.instance.setStatus(id, newStatus);
      if (mounted) {
        setState(() => _servicio = {..._servicio, 'status': newStatus});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el estado.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BeneficioScannerScreen()),
    );
    if (result == true) await _loadRedeemedState();
  }

  @override
  Widget build(BuildContext context) {
    final id = _servicio['id'] as String?;
    final title = _servicio['title'] as String? ?? 'Servicio';
    final description = _servicio['description'] as String?;
    final category = _servicio['category'] as String?;
    final companyName = _servicio['company_name'] as String?;
    final status = _servicio['status'] as String? ?? 'activo';
    final isActive = status == 'activo';
    final pricingType = _servicio['pricing_type'] as String? ?? 'costo';
    final isCashback = pricingType == 'cashback';
    final hcCost = (_servicio['hc_cost'] as num?)?.toInt();
    final hcReward = (_servicio['hc_reward'] as num?)?.toInt();
    final hcLabel = isCashback ? '+$hcReward HC' : '$hcCost HC';
    final maxRedemptions = (_servicio['max_redemptions'] as num?)?.toInt();
    final redemptionsCount =
        (_servicio['redemptions_count'] as num?)?.toInt() ?? 0;
    final createdAt = DateTime.tryParse(
      _servicio['created_at'] as String? ?? '',
    );
    final latitude = (_servicio['latitude'] as num?)?.toDouble();
    final longitude = (_servicio['longitude'] as num?)?.toDouble();
    final location = _servicio['location'] as String?;

    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Detalle del servicio'),
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
                    if (category != null && category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (_isOwner) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isActive ? 'Activo' : 'Inactivo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (companyName != null && companyName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.apartment,
                        color: Colors.white,
                        size: 15,
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

          if (latitude != null && longitude != null) ...[
            const _SectionLabel('Ubicación'),
            MiniMap(
              latitude: latitude,
              longitude: longitude,
              label: location,
              otherLocations: _otherServicios,
              onTapOtherLocation: _openOtherServicio,
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
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.event,
              label:
                  'Publicado el ${createdAt.day}/${createdAt.month}/${createdAt.year}',
            ),
          ],
          const SizedBox(height: 28),

          if (_isOwner) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: id == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ServicioQrScreen(
                            servicioId: id,
                            servicioTitle: title,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.qr_code),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primarioRojo,
                  side: const BorderSide(color: AppColors.primarioRojo),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: const Text(
                  'Mostrar QR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _isUpdating ? null : _toggleStatus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gris700,
                  side: BorderSide(color: AppColors.gris300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isActive ? 'Desactivar' : 'Activar'),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_hasRedeemed == null || _hasRedeemed == true)
                    ? null
                    : _openScanner,
                icon: const Icon(Icons.qr_code_scanner),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primarioRojo,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.gris300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: Text(
                  _hasRedeemed == true
                      ? 'Ya canjeaste este servicio'
                      : 'Escanear para canjear',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
