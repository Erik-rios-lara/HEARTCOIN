import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra inferior flotante compartida (Home / Buscar / centro elevado
/// en negro con un corazón / Tus acciones / Perfil), reutilizada en
/// las pantallas rediseñadas (billetera, detalle de beneficio, etc.).
class AppBottomNavBar extends StatelessWidget {
  final VoidCallback onTapHome;
  final VoidCallback onTapSearch;
  final VoidCallback onTapActions;
  final VoidCallback onTapProfile;

  const AppBottomNavBar({
    super.key,
    required this.onTapHome,
    required this.onTapSearch,
    required this.onTapActions,
    required this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.primarioBlanco,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: AppColors.primarioNegro.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavIcon(icon: Icons.home_rounded, onTap: onTapHome),
            _NavIcon(icon: Icons.search_rounded, onTap: onTapSearch),
            const _CenterNavIcon(),
            _NavIcon(
              icon: Icons.volunteer_activism_rounded,
              onTap: onTapActions,
            ),
            _NavIcon(icon: Icons.person_outline_rounded, onTap: onTapProfile),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, size: 24, color: AppColors.gris600),
      ),
    );
  }
}

class _CenterNavIcon extends StatelessWidget {
  const _CenterNavIcon();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -14),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primarioNegro,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primarioNegro.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.favorite, color: Colors.white, size: 24),
      ),
    );
  }
}
