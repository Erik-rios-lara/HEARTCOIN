import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/empresa/company_dashboard_service.dart';
import '../../services/common/notification_service.dart';
import '../../theme/app_colors.dart';
import 'company_beneficios_screen.dart';
import 'company_servicios_screen.dart';
import 'create_beneficio_screen.dart';
import '../common/notifications_screen.dart';

/// Home del rol "empresa": dashboard con sus beneficios publicados
/// y el HC que han movido (cobrado o entregado en cashback).
class HomeCompanyScreen extends StatefulWidget {
  const HomeCompanyScreen({super.key});

  @override
  State<HomeCompanyScreen> createState() => _HomeCompanyScreenState();
}

class _HomeCompanyScreenState extends State<HomeCompanyScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  CompanyDashboardStats _stats = CompanyDashboardStats.empty;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
  }

  Future<void> _loadProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _supabase
          .from('company_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (mounted) setState(() => _profile = data);
    } catch (_) {
      // Si falla, el encabezado simplemente muestra el saludo genérico.
    }
  }

  Future<void> _loadStats() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final stats = await CompanyDashboardService.instance.fetchStats(userId);
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // Si falla, el resumen simplemente se queda en ceros.
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyName = _profile?['company_name'] as String? ?? 'tu empresa';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.gris100,
      drawer: _CompanyDrawer(profile: _profile),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: NotificationService.instance.notificationsStream(),
              builder: (context, snapshot) {
                final hasUnread = (snapshot.data ?? []).any(
                  (n) => n['is_read'] == false,
                );
                return _Header(
                  companyName: companyName,
                  hasUnreadNotifications: hasUnread,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  onNotificationsTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                  onNewBeneficio: () async {
                    final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const CreateBeneficioScreen(),
                      ),
                    );
                    if (created == true && mounted) _loadStats();
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            _StatsSummary(stats: _stats),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CompanyBeneficiosScreen(),
                ),
              ),
              icon: const Icon(Icons.local_offer_outlined),
              label: const Text('Ver todos mis beneficios'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.primarioRojo,
                side: const BorderSide(color: AppColors.primarioRojo),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _CompanyBottomNavBar(),
    );
  }
}

/// ============================================================
/// ENCABEZADO: menú + logo + título + bienvenida + tarjeta destacada
/// ============================================================
class _Header extends StatelessWidget {
  final String companyName;
  final bool hasUnreadNotifications;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onNewBeneficio;

  const _Header({
    required this.companyName,
    required this.hasUnreadNotifications,
    required this.onMenuTap,
    required this.onNotificationsTap,
    required this.onNewBeneficio,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onMenuTap,
                    child: Icon(
                      Icons.menu_rounded,
                      color: AppColors.primarioNegro,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.favorite,
                    color: AppColors.primarioRojo,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Heart Coin',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarioNegro,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onNotificationsTap,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.primarioNegro,
                          size: 24,
                        ),
                        if (hasUnreadNotifications)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppColors.primarioRojo,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarioNegro,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bienvenido, $companyName',
                style: TextStyle(fontSize: 13, color: AppColors.gris600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _HeroCard(onTap: onNewBeneficio),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 150,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primarioNegro, AppColors.rojoOscuro2],
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primarioRojo,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Nuevo beneficio',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// RESUMEN: beneficios activos, por vencer, canjes y HC movidos
/// ============================================================
class _StatsSummary extends StatelessWidget {
  final CompanyDashboardStats stats;
  const _StatsSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        label: 'Beneficios activos',
        value: '${stats.activeCount}',
        icon: Icons.local_offer_outlined,
      ),
      (
        label: 'Por vencer (7 días)',
        value: '${stats.expiringSoonCount}',
        icon: Icons.hourglass_bottom,
      ),
      (
        label: 'Canjes totales',
        value: '${stats.totalRedemptions}',
        icon: Icons.qr_code_scanner,
      ),
      (
        label: 'HC cobrados',
        value: '${stats.hcCollectedSpend}',
        icon: Icons.toll,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.gris200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de beneficios',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Datos en tiempo real de tus beneficios.',
            style: TextStyle(fontSize: 11, color: AppColors.gris600),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarioBlanco,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.icon,
                          color: AppColors.primarioRojo,
                          size: 20,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.value,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarioNegro,
                          ),
                        ),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.gris600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// MENÚ LATERAL
/// ============================================================
class _CompanyDrawer extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _CompanyDrawer({required this.profile});

  @override
  Widget build(BuildContext context) {
    final companyName = profile?['company_name'] as String? ?? 'Empresa';
    final email = profile?['corporate_email'] as String? ?? '';

    return Drawer(
      backgroundColor: AppColors.primarioBlanco,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.gris200,
                    child: Icon(
                      Icons.storefront_outlined,
                      color: AppColors.gris600,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarioNegro,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.gris600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.gris200),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.local_offer_outlined,
                color: AppColors.gris700,
              ),
              title: Text(
                'Mis beneficios',
                style: TextStyle(
                  color: AppColors.primarioNegro,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/mis-beneficios');
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: AppColors.gris700),
              title: Text(
                'Configuración',
                style: TextStyle(
                  color: AppColors.primarioNegro,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/settings');
              },
            ),
            const Spacer(),
            Divider(height: 1, color: AppColors.gris200),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmSignOut(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarioRojo,
                    foregroundColor: AppColors.primarioBlanco,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primarioRojo,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }
}

/// ============================================================
/// TAB INFERIOR (sin botón central: home, beneficios, canjes, ajustes)
/// ============================================================
class _CompanyBottomNavBar extends StatelessWidget {
  const _CompanyBottomNavBar();

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
            const _NavIcon(icon: Icons.home_rounded, isSelected: true),
            _NavIcon(
              icon: Icons.local_offer_outlined,
              isSelected: false,
              onTap: () => Navigator.of(context).pushNamed('/mis-beneficios'),
            ),
            _NavIcon(
              icon: Icons.design_services_outlined,
              isSelected: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CompanyServiciosScreen(),
                ),
              ),
            ),
            const _NavIcon(icon: Icons.description_outlined, isSelected: false),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _NavIcon({required this.icon, required this.isSelected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          size: 24,
          color: isSelected ? AppColors.primarioRojo : AppColors.gris600,
        ),
      ),
    );
  }
}
