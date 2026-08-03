import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Vista de un certificado individual, con formato de diploma.
class CertificadoDetailScreen extends StatelessWidget {
  final String recipientName;
  final Map<String, dynamic> certificado;

  const CertificadoDetailScreen({
    super.key,
    required this.recipientName,
    required this.certificado,
  });

  static const _categoryLabels = {
    'Voluntariado': 'voluntariado',
    'Social': 'acción social',
    'Crowdfunding': 'crowdfunding',
    'Ahorro': 'ahorro',
  };

  static const _categoryIcons = {
    'Voluntariado': Icons.groups,
    'Crowdfunding': Icons.volunteer_activism,
    'Social': Icons.diversity_3,
    'Ahorro': Icons.savings,
  };

  @override
  Widget build(BuildContext context) {
    final iniciativa =
        certificado['iniciativas'] as Map<String, dynamic>? ?? {};
    final title = iniciativa['title'] as String? ?? 'Iniciativa';
    final category = iniciativa['category'] as String? ?? '';
    final organizationName = iniciativa['organization_name'] as String?;
    final checkinDate = DateTime.tryParse(
      certificado['created_at'] as String? ?? '',
    );

    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Certificado'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primarioBlanco,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.rojoClaro1, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primarioNegro.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primarioRojo, AppColors.rojoOscuro1],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'CERTIFICADO DE PARTICIPACIÓN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.primarioRojo,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Se otorga el presente reconocimiento a',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.gris600),
              ),
              const SizedBox(height: 8),
              Text(
                recipientName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarioNegro,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'por su participación confirmada en',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.gris600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _categoryIcons[category] ?? Icons.favorite,
                    size: 18,
                    color: AppColors.primarioRojo,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primarioNegro,
                      ),
                    ),
                  ),
                ],
              ),
              if (category.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Categoría: ${_categoryLabels[category] ?? category}',
                  style: TextStyle(fontSize: 12, color: AppColors.gris600),
                ),
              ],
              if (organizationName != null && organizationName.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(height: 1, color: AppColors.gris200),
                const SizedBox(height: 16),
                Text(
                  'Organizado por',
                  style: TextStyle(fontSize: 11, color: AppColors.gris600),
                ),
                const SizedBox(height: 2),
                Text(
                  organizationName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primarioNegro,
                  ),
                ),
              ],
              if (checkinDate != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Fecha de participación: ${checkinDate.day}/${checkinDate.month}/${checkinDate.year}',
                  style: TextStyle(fontSize: 12, color: AppColors.gris600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
