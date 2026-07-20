import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';
import '../services/org_dashboard_service.dart';
import '../theme/app_colors.dart';
import 'create_org_iniciativa_screen.dart';
import 'notifications_screen.dart';

/// Home del rol "organización": dashboard con resumen de actividad
/// y evolución semanal de votos recibidos por sus campañas.
class HomeOrganizationScreen extends StatefulWidget {
  const HomeOrganizationScreen({super.key});

  @override
  State<HomeOrganizationScreen> createState() => _HomeOrganizationScreenState();
}

class _HomeOrganizationScreenState extends State<HomeOrganizationScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  OrgDashboardStats _stats = OrgDashboardStats.empty;

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
          .from('organization_profiles')
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
      final stats = await OrgDashboardService.instance.fetchStats(userId);
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // Si falla, el resumen simplemente se queda en ceros.
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizationName =
        _profile?['organization_name'] as String? ?? 'tu organización';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.gris100,
      drawer: _OrgDrawer(profile: _profile),
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
                  organizationName: organizationName,
                  hasUnreadNotifications: hasUnread,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  onNotificationsTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                  onNewInitiative: () async {
                    final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const CreateOrgIniciativaScreen(),
                      ),
                    );
                    if (created == true && mounted) setState(() {});
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            _ActivitySummary(stats: _stats),
            const SizedBox(height: 24),
            _WeeklyVotesChart(weeklyVotes: _stats.weeklyVotes),
          ],
        ),
      ),
      bottomNavigationBar: const _OrgBottomNavBar(),
    );
  }
}

/// ============================================================
/// ENCABEZADO: menú + logo + título + bienvenida + tarjeta destacada
/// ============================================================
class _Header extends StatelessWidget {
  final String organizationName;
  final bool hasUnreadNotifications;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onNewInitiative;

  const _Header({
    required this.organizationName,
    required this.hasUnreadNotifications,
    required this.onMenuTap,
    required this.onNotificationsTap,
    required this.onNewInitiative,
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
                'Bienvenida, $organizationName',
                style: TextStyle(fontSize: 13, color: AppColors.gris600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _HeroCard(onTap: onNewInitiative),
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
              child: Opacity(
                opacity: 0.35,
                child: Image.asset(
                  'assets/portada.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, _, _) => const SizedBox.expand(),
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
                  'NEW Initiative',
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
/// WIDGET PRINCIPAL: resumen de actividad
/// ============================================================
class _ActivitySummary extends StatelessWidget {
  final OrgDashboardStats stats;
  const _ActivitySummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        label: 'Iniciativas activas',
        value: '${stats.activeCount}',
        icon: Icons.flag_outlined,
      ),
      (
        label: 'Votos recibidos',
        value: '${stats.votesTotal}',
        icon: Icons.how_to_vote,
      ),
      (label: 'HC otorgados', value: 'Pendiente', icon: Icons.toll),
      (
        label: 'Personas alcanzadas',
        value: '${stats.reachedPeople}',
        icon: Icons.groups_outlined,
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
            'Resumen de actividad',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Datos en tiempo real de tus campañas.',
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
/// GRÁFICA: votos recibidos por día (últimos 7 días)
/// ============================================================
class _WeeklyVotesChart extends StatelessWidget {
  final List<int> weeklyVotes;
  const _WeeklyVotesChart({required this.weeklyVotes});

  static const _labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final values = weeklyVotes.map((v) => v.toDouble()).toList();
    final maxValue = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarioBlanco,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votos recibidos esta semana',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_labels.length, (index) {
                final heightFactor = values[index] / maxValue;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          values[index].toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.gris600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: FractionallySizedBox(
                            alignment: Alignment.bottomCenter,
                            heightFactor: heightFactor.clamp(0.05, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primarioRojo,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _labels[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gris700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// MENÚ LATERAL
/// ============================================================
class _OrgDrawer extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _OrgDrawer({required this.profile});

  @override
  Widget build(BuildContext context) {
    final orgName = profile?['organization_name'] as String? ?? 'Organización';
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
                      Icons.apartment,
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
                          orgName,
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
                Icons.how_to_vote_outlined,
                color: AppColors.gris700,
              ),
              title: Text(
                'Monitor de votaciones',
                style: TextStyle(
                  color: AppColors.primarioNegro,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/votaciones-monitor');
              },
            ),
            ListTile(
              leading: Icon(Icons.groups_outlined, color: AppColors.gris700),
              title: Text(
                'Comunidad',
                style: TextStyle(
                  color: AppColors.primarioNegro,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/comunidad');
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
/// TAB INFERIOR (sin el botón central rojo)
/// ============================================================
class _OrgBottomNavBar extends StatelessWidget {
  const _OrgBottomNavBar();

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
              icon: Icons.flag_outlined,
              isSelected: false,
              onTap: () => Navigator.of(context).pushNamed('/mis-iniciativas'),
            ),
            const _NavIcon(icon: Icons.check_circle_outline, isSelected: false),
            const _NavIcon(icon: Icons.groups_outlined, isSelected: false),
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
