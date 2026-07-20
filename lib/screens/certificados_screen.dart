import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/certificado_service.dart';
import '../theme/app_colors.dart';
import 'certificado_detail_screen.dart';

/// Certificados de participación, generados a partir de cada
/// check-in confirmado en una iniciativa.
class CertificadosScreen extends StatefulWidget {
  const CertificadosScreen({super.key});

  @override
  State<CertificadosScreen> createState() => _CertificadosScreenState();
}

class _CertificadosScreenState extends State<CertificadosScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  String _fullName = 'Usuario HeartCoin';
  List<Map<String, dynamic>> _certificados = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final userId = _client.auth.currentUser?.id;
      final profile = userId == null
          ? null
          : await _client
                .from('personal_profiles')
                .select('full_name')
                .eq('id', userId)
                .maybeSingle();
      final certificados = await CertificadoService.instance
          .fetchMyCertificados();

      if (mounted) {
        setState(() {
          _fullName = profile?['full_name'] as String? ?? 'Usuario HeartCoin';
          _certificados = certificados;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const _categoryLabels = {
    'Voluntariado': 'Voluntariado',
    'Social': 'Acción social',
    'Crowdfunding': 'Crowdfunding',
    'Ahorro': 'Ahorro',
  };

  static const _categoryIcons = {
    'Voluntariado': Icons.groups,
    'Crowdfunding': Icons.volunteer_activism,
    'Social': Icons.diversity_3,
    'Ahorro': Icons.savings,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Mis certificados'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            )
          : RefreshIndicator(
              color: AppColors.primarioRojo,
              onRefresh: _load,
              child: _certificados.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 80,
                      ),
                      children: [
                        Icon(
                          Icons.workspace_premium_outlined,
                          size: 56,
                          color: AppColors.gris400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aún no tienes certificados.\nHaz check-in en una iniciativa para ganar tu primero.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.gris600),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _certificados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final certificado = _certificados[index];
                        final iniciativa =
                            certificado['iniciativas']
                                as Map<String, dynamic>? ??
                            {};
                        final title =
                            iniciativa['title'] as String? ?? 'Iniciativa';
                        final category =
                            iniciativa['category'] as String? ?? '';
                        final organizationName =
                            iniciativa['organization_name'] as String?;
                        final checkinDate = DateTime.tryParse(
                          certificado['created_at'] as String? ?? '',
                        );

                        return Material(
                          color: AppColors.primarioBlanco,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CertificadoDetailScreen(
                                  recipientName: _fullName,
                                  certificado: certificado,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.rojoClaro1.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _categoryIcons[category] ??
                                          Icons.workspace_premium,
                                      color: AppColors.primarioRojo,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primarioNegro,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            _categoryLabels[category] ??
                                                category,
                                            ?organizationName,
                                          ].join(' · '),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.gris600,
                                          ),
                                        ),
                                        if (checkinDate != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '${checkinDate.day}/${checkinDate.month}/${checkinDate.year}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.gris600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: AppColors.gris400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
