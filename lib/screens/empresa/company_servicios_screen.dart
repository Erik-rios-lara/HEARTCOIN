import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/common/servicio_service.dart';
import '../../theme/app_colors.dart';
import 'create_servicio_screen.dart';
import '../common/servicio_detail_screen.dart';
import 'servicio_qr_screen.dart';

/// Catálogo de servicios que ofrece la empresa (ej. consultoría,
/// diseño, capacitación), independiente de los beneficios canjeables
/// con HC.
class CompanyServiciosScreen extends StatefulWidget {
  const CompanyServiciosScreen({super.key});

  @override
  State<CompanyServiciosScreen> createState() => _CompanyServiciosScreenState();
}

class _CompanyServiciosScreenState extends State<CompanyServiciosScreen> {
  final _client = Supabase.instance.client;

  List<Map<String, dynamic>> _ownServicios(List<Map<String, dynamic>> all) {
    final userId = _client.auth.currentUser?.id;
    return all.where((s) => s['company_id'] == userId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Mis servicios'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateServicioScreen()),
          );
          if (created == true && mounted) setState(() {});
        },
        backgroundColor: AppColors.primarioRojo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ServicioService.instance.myServiciosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            );
          }

          final own = _ownServicios(snapshot.data ?? []);

          if (own.isEmpty) {
            return Center(
              child: Text(
                'Aún no has publicado servicios.',
                style: TextStyle(color: AppColors.gris600),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: own
                .map(
                  (servicio) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ServicioCard(servicio: servicio),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _ServicioCard extends StatelessWidget {
  final Map<String, dynamic> servicio;
  const _ServicioCard({required this.servicio});

  @override
  Widget build(BuildContext context) {
    final id = servicio['id'] as String?;
    final title = servicio['title'] as String? ?? 'Servicio';
    final description = servicio['description'] as String?;
    final category = servicio['category'] as String?;
    final status = servicio['status'] as String? ?? 'activo';
    final isActive = status == 'activo';
    final isCashback = servicio['pricing_type'] == 'cashback';
    final hcCost = (servicio['hc_cost'] as num?)?.toInt();
    final hcReward = (servicio['hc_reward'] as num?)?.toInt();
    final hcLabel = isCashback
        ? '+$hcReward HC por canje'
        : '$hcCost HC por canje';
    final redemptionsCount =
        (servicio['redemptions_count'] as num?)?.toInt() ?? 0;
    final maxRedemptions = (servicio['max_redemptions'] as num?)?.toInt();

    return Material(
      color: AppColors.primarioBlanco,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ServicioDetailScreen(servicio: servicio),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (category != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.rojoClaro1.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primarioRojo,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ] else
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
              const SizedBox(height: 2),
              Text(
                maxRedemptions != null
                    ? '$redemptionsCount / $maxRedemptions canjes'
                    : '$redemptionsCount canjes',
                style: TextStyle(fontSize: 12, color: AppColors.gris600),
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.gris700),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: id == null
                          ? null
                          : () async {
                              await ServicioService.instance.setStatus(
                                id,
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
                                builder: (_) => ServicioQrScreen(
                                  servicioId: id,
                                  servicioTitle: title,
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
