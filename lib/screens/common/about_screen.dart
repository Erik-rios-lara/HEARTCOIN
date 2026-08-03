import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'privacy_policy_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Acerca de'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primarioRojo, AppColors.rojoOscuro1],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'HeartCoin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primarioNegro,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Versión 1.0.0',
                  style: TextStyle(fontSize: 12, color: AppColors.gris600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _InfoTile(
            icon: Icons.info_outline,
            title: 'Sobre la app',
            subtitle:
                'App social de impacto: convierte el voluntariado, las donaciones '
                'y las iniciativas comunitarias en HeartCoins canjeables.',
          ),
          const SizedBox(height: 12),
          const _InfoTile(
            icon: Icons.mail_outline,
            title: 'Contacto',
            subtitle: 'lab@theoriginallab.com',
          ),
          const SizedBox(height: 12),
          const _InfoTile(
            icon: Icons.description_outlined,
            title: 'Términos y condiciones',
            subtitle: 'Próximamente',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de privacidad',
            subtitle: 'Cómo tratamos tus datos personales',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarioBlanco,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primarioRojo, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primarioNegro,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: AppColors.gris600),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: AppColors.gris400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
