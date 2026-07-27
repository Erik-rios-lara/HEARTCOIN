import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/beneficio_service.dart';
import '../services/current_location.dart';
import '../services/location_preference_controller.dart';
import '../services/notification_service.dart';
import '../services/ranking_service.dart';
import '../services/servicio_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/floating_location_card.dart';
import '../widgets/map_marker_icons.dart';
import '../widgets/map_type_button.dart';
import 'beneficio_detail_screen.dart';
import 'beneficio_scanner_screen.dart';
import 'notifications_screen.dart';
import 'servicio_detail_screen.dart';

enum _WalletTab { wallet, beneficios, servicios, puntos }

/// Billetera de HeartCoin del usuario: balance real, beneficios
/// disponibles para canjear (vía QR, con mapa y buscador), historial
/// de movimientos y ranking de participación.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  _WalletTab _tab = _WalletTab.beneficios;

  void _openMap() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _BeneficiosMapaScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _WalletHeroHeader(
              onMenuTap: () => Navigator.of(context).maybePop(),
              tab: _tab,
              onScan: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BeneficioScannerScreen(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _TabPillRow(
              selected: _tab,
              onSelected: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: switch (_tab) {
                _WalletTab.wallet => const _HistorialTab(),
                _WalletTab.beneficios => _BeneficiosTab(onOpenMap: _openMap),
                _WalletTab.servicios => const _ServiciosTab(),
                _WalletTab.puntos => const _RankingTab(),
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        onTapHome: () => Navigator.of(context).maybePop(),
        onTapSearch: () => Navigator.of(context).pushNamed('/search'),
        onTapActions: () => Navigator.of(context).pushNamed('/mis-acciones'),
        onTapProfile: () => Navigator.of(context).pushNamed('/profile'),
      ),
    );
  }
}

/// ============================================================
/// ENCABEZADO: fondo degradado con curva + menú/notificaciones +
/// ícono de corazón en anillo + balance (solo en la pestaña Wallet).
/// ============================================================
class _WalletHeroHeader extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onScan;
  final _WalletTab tab;

  const _WalletHeroHeader({
    required this.onMenuTap,
    required this.onScan,
    required this.tab,
  });

  String _formatted(int balance) {
    final text = balance.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final showHero = tab == _WalletTab.wallet;

    return ClipPath(
      clipper: _HeroCurveClipper(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, 4, 20, showHero ? 24 : 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFBD9DE), Color(0xFFFFFFFF)],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: onMenuTap,
                  child: const Icon(
                    Icons.menu_rounded,
                    color: AppColors.primarioNegro,
                    size: 26,
                  ),
                ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: NotificationService.instance.notificationsStream(),
                  builder: (context, snapshot) {
                    final hasUnread = (snapshot.data ?? []).any(
                      (n) => n['is_read'] == false,
                    );
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.primarioNegro,
                            size: 26,
                          ),
                          if (hasUnread)
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
                    );
                  },
                ),
              ],
            ),
            if (showHero) ...[
              const SizedBox(height: 12),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primarioRojo.withValues(alpha: 0.35),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primarioRojo,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Balance',
                style: TextStyle(fontSize: 13, color: AppColors.gris600),
              ),
              const SizedBox(height: 2),
              StreamBuilder<Map<String, dynamic>?>(
                stream: WalletService.instance.profileStream(),
                builder: (context, snapshot) {
                  final balance =
                      (snapshot.data?['hc_balance'] as num?)?.toInt() ?? 0;
                  return Text(
                    _formatted(balance),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarioNegro,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onScan,
                child: Text(
                  'Escanear para canjear',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primarioRojo,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Curva diagonal decorativa del fondo del header (rosa → blanco).
class _HeroCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height,
        size.width,
        size.height * 0.62,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Selector Wallet / Beneficios / Servicios / Puntos (Historial /
/// Beneficios / Servicios / Ranking).
class _TabPillRow extends StatelessWidget {
  final _WalletTab selected;
  final ValueChanged<_WalletTab> onSelected;
  const _TabPillRow({required this.selected, required this.onSelected});

  static const _labels = {
    _WalletTab.wallet: 'Wallet',
    _WalletTab.beneficios: 'Beneficios',
    _WalletTab.servicios: 'Servicios',
    _WalletTab.puntos: 'Puntos',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: _WalletTab.values.map((tab) {
          final isSelected = tab == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              onTap: () => onSelected(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primarioRojo
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[tab]!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.primarioNegro,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// ============================================================
/// PESTAÑA BENEFICIOS: buscador, categorías, Destacados / Para ti
/// ============================================================
class _BeneficiosTab extends StatefulWidget {
  final VoidCallback onOpenMap;
  const _BeneficiosTab({required this.onOpenMap});

  @override
  State<_BeneficiosTab> createState() => _BeneficiosTabState();
}

class _BeneficiosTabState extends State<_BeneficiosTab> {
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

  final _searchController = TextEditingController();
  String _query = '';
  String? _category;
  bool _sortCercanos = false;
  LocationCaptureResult? _userLocation;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    if (!LocationPreferenceController.instance.enabled.value) return;
    try {
      final result = await captureCurrentLocation();
      if (mounted) setState(() => _userLocation = result);
    } catch (_) {
      // Sin ubicación disponible: "Cercanos" simplemente no se podrá calcular.
    }
  }

  double _distanceTo(Map<String, dynamic> beneficio) {
    final userLocation = _userLocation;
    final lat = (beneficio['latitude'] as num?)?.toDouble();
    final lng = (beneficio['longitude'] as num?)?.toDouble();
    if (userLocation == null || lat == null || lng == null) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      lat,
      lng,
    );
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primarioBlanco,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ordenar por',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Recientes'),
                    selected: !_sortCercanos,
                    onSelected: (_) => setSheetState(
                      () => setState(() => _sortCercanos = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Cercanos'),
                    selected: _sortCercanos,
                    onSelected: (_) => setSheetState(
                      () => setState(() => _sortCercanos = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    widget.onOpenMap();
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver en el mapa'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primarioRojo,
                    side: const BorderSide(color: AppColors.primarioRojo),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(sheetContext).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    var list = all.where((b) => b['status'] == 'activo').toList();
    if (_category != null) {
      list = list.where((b) => b['benefit_type'] == _category).toList();
    }
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where(
            (b) => (b['title'] as String? ?? '').toLowerCase().contains(query),
          )
          .toList();
    }
    if (_sortCercanos) {
      list.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: WalletService.instance.activeBeneficiosStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primarioRojo),
          );
        }

        final filtered = _applyFilters(snapshot.data ?? []);
        final destacados = filtered
            .where((b) => b['destacado'] == true)
            .toList();
        final paraTi = filtered.where((b) => b['destacado'] != true).toList();

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SearchBar(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                onFilterTap: _openFilters,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _CategoryChip(
                    label: 'Todos',
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final entry in _typeLabels.entries) ...[
                    const SizedBox(width: 8),
                    _CategoryChip(
                      label: entry.value,
                      selected: _category == entry.key,
                      onTap: () => setState(
                        () => _category = _category == entry.key
                            ? null
                            : entry.key,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (destacados.isNotEmpty) ...[
              const _SectionHeader(
                icon: Icons.star_rounded,
                label: 'Destacados',
              ),
              const SizedBox(height: 12),
              _BeneficioCarousel(
                beneficios: destacados,
                typeIcons: _typeIcons,
                typeLabels: _typeLabels,
              ),
              const SizedBox(height: 24),
            ],
            const _SectionHeader(
              icon: Icons.volunteer_activism_rounded,
              label: 'Para ti',
            ),
            const SizedBox(height: 12),
            if (paraTi.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'No hay beneficios que coincidan con tu búsqueda.',
                  style: TextStyle(color: AppColors.gris600),
                ),
              )
            else
              _BeneficioCarousel(
                beneficios: paraTi,
                typeIcons: _typeIcons,
                typeLabels: _typeLabels,
              ),
          ],
        );
      },
    );
  }
}

/// ============================================================
/// PESTAÑA SERVICIOS: servicios activos de empresas, con buscador
/// y filtro por categoría (mismo patrón que la pestaña Beneficios).
/// ============================================================
class _ServiciosTab extends StatefulWidget {
  const _ServiciosTab();

  @override
  State<_ServiciosTab> createState() => _ServiciosTabState();
}

class _ServiciosTabState extends State<_ServiciosTab> {
  static const _categories = ['Alimentos', 'Moda', 'Salud', 'Educación', 'Otro'];

  final _searchController = TextEditingController();
  String? _category;
  bool _isLoading = true;
  List<Map<String, dynamic>> _servicios = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final servicios = await ServicioService.instance.fetchActiveServicios(
        category: _category,
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _servicios = servicios);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primarioRojo,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primarioBlanco,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.only(left: 16),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Buscar servicios',
                hintStyle: TextStyle(color: AppColors.gris600, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: Icon(Icons.search, color: AppColors.gris600, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryChip(
                  label: 'Todos',
                  selected: _category == null,
                  onTap: () {
                    setState(() => _category = null);
                    _load();
                  },
                ),
                for (final category in _categories) ...[
                  const SizedBox(width: 8),
                  _CategoryChip(
                    label: category,
                    selected: _category == category,
                    onTap: () {
                      setState(
                        () => _category = _category == category
                            ? null
                            : category,
                      );
                      _load();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primarioRojo),
              ),
            )
          else if (_servicios.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No hay servicios que coincidan con tu búsqueda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.gris600),
                ),
              ),
            )
          else
            ..._servicios.map(
              (servicio) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ServicioCard(servicio: servicio),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServicioCard extends StatelessWidget {
  final Map<String, dynamic> servicio;
  const _ServicioCard({required this.servicio});

  @override
  Widget build(BuildContext context) {
    final title = servicio['title'] as String? ?? 'Servicio';
    final description = servicio['description'] as String?;
    final category = servicio['category'] as String?;
    final companyName = servicio['company_name'] as String?;
    final isCashback = servicio['pricing_type'] == 'cashback';
    final hcCost = (servicio['hc_cost'] as num?)?.toInt();
    final hcReward = (servicio['hc_reward'] as num?)?.toInt();
    final hcLabel = isCashback ? '+$hcReward HC' : '$hcCost HC';
    final location = servicio['location'] as String?;

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
          padding: const EdgeInsets.all(14),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gris200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hcLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primarioNegro,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarioNegro,
                ),
              ),
              if (companyName != null && companyName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.apartment, size: 13, color: AppColors.gris600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gris700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (location != null && location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 13,
                      color: AppColors.gris600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.gris600),
                      ),
                    ),
                  ],
                ),
              ],
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: AppColors.gris700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarioBlanco,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Buscar beneficios',
                hintStyle: TextStyle(color: AppColors.gris600, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Container(width: 1, height: 22, color: AppColors.gris300),
          IconButton(
            onPressed: onFilterTap,
            icon: Icon(Icons.tune, color: AppColors.gris600, size: 20),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarioNegro : AppColors.primarioBlanco,
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: AppColors.gris300),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.gris700,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primarioRojo,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
        ],
      ),
    );
  }
}

class _BeneficioCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> beneficios;
  final Map<String, IconData> typeIcons;
  final Map<String, String> typeLabels;

  const _BeneficioCarousel({
    required this.beneficios,
    required this.typeIcons,
    required this.typeLabels,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 194,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: beneficios.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final beneficio = beneficios[index];
          final type = beneficio['benefit_type'] as String?;
          return _BeneficioCard(
            beneficio: beneficio,
            typeIcon: typeIcons[type],
            typeLabel: typeLabels[type],
          );
        },
      ),
    );
  }
}

class _BeneficioCard extends StatelessWidget {
  final Map<String, dynamic> beneficio;
  final IconData? typeIcon;
  final String? typeLabel;

  const _BeneficioCard({
    required this.beneficio,
    this.typeIcon,
    this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final title = beneficio['title'] as String? ?? 'Beneficio';
    final description = beneficio['description'] as String?;
    final imageUrl = beneficio['image_url'] as String?;
    final isCashback = beneficio['benefit_type'] == 'cashback';
    final hcCost = (beneficio['hc_cost'] as num?)?.toInt();
    final hcReward = (beneficio['hc_reward'] as num?)?.toInt();
    final hcLabel = isCashback ? '+$hcReward HC' : '$hcCost HC';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BeneficioDetailScreen(beneficio: beneficio),
        ),
      ),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.primarioBlanco,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primarioNegro.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover)
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
                              typeIcon ?? Icons.card_giftcard,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 32,
                            ),
                          ),
                  ),
                ),
                if (typeLabel != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        typeLabel!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primarioNegro,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarioNegro,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppColors.gris600),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.rojoClaro1.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hcLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primarioRojo,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// MAPA DE BENEFICIOS (pantalla aparte, se abre desde el filtro de
/// la pestaña Beneficios en vez de ser su propia pestaña)
/// ============================================================
class _BeneficiosMapaScreen extends StatefulWidget {
  const _BeneficiosMapaScreen();

  @override
  State<_BeneficiosMapaScreen> createState() => _BeneficiosMapaScreenState();
}

class _BeneficiosMapaScreenState extends State<_BeneficiosMapaScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _businesses = [];
  LocationCaptureResult? _userLocation;
  Map<String, dynamic>? _selected;
  BitmapDescriptor? _businessIcon;
  BitmapDescriptor? _meIcon;
  MapType _mapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadBeneficios(), _loadLocation(), _loadIcons()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadIcons() async {
    final results = await Future.wait([
      heartPinBitmap(color: AppColors.primarioRojo, size: 40),
      dotBitmap(color: AppColors.primarioRojo, size: 22),
    ]);
    if (!mounted) return;
    setState(() {
      _businessIcon = results[0];
      _meIcon = results[1];
    });
  }

  Future<void> _loadBeneficios() async {
    try {
      final beneficios = await BeneficioService.instance
          .fetchActiveBeneficios();
      final withLocation = beneficios
          .where((b) => b['latitude'] != null && b['longitude'] != null)
          .toList();
      if (!mounted) return;
      setState(() => _businesses = _groupByBusiness(withLocation));
    } catch (_) {
      // Sin beneficios cargados, el mapa simplemente se queda vacío.
    }
  }

  /// Un punto en el mapa representa un negocio (empresa + ubicación),
  /// no un beneficio individual: si una empresa publicó varios
  /// beneficios en el mismo lugar, se agrupan en un solo pin.
  List<Map<String, dynamic>> _groupByBusiness(
    List<Map<String, dynamic>> beneficios,
  ) {
    final groups = <String, Map<String, dynamic>>{};
    for (final beneficio in beneficios) {
      final lat = (beneficio['latitude'] as num).toDouble();
      final lng = (beneficio['longitude'] as num).toDouble();
      final key =
          '${beneficio['company_id']}_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}';
      final group = groups.putIfAbsent(
        key,
        () => {
          'key': key,
          'company_name': beneficio['company_name'] ?? 'Negocio',
          'location': beneficio['location'],
          'latitude': lat,
          'longitude': lng,
          'beneficios': <Map<String, dynamic>>[],
        },
      );
      (group['beneficios'] as List<Map<String, dynamic>>).add(beneficio);
    }
    return groups.values.toList();
  }

  Future<void> _loadLocation() async {
    if (!LocationPreferenceController.instance.enabled.value) return;
    try {
      final result = await captureCurrentLocation();
      if (mounted) setState(() => _userLocation = result);
    } catch (_) {
      // Sin ubicación disponible, el mapa se centra en los beneficios.
    }
  }

  void _openBeneficio(Map<String, dynamic> beneficio) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BeneficioDetailScreen(beneficio: beneficio),
      ),
    );
  }

  void _showBusinessBeneficios(Map<String, dynamic> business) {
    setState(() => _selected = null);
    final beneficios = (business['beneficios'] as List)
        .cast<Map<String, dynamic>>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primarioBlanco,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                business['company_name'] as String,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarioNegro,
                ),
              ),
              if ((business['location'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  business['location'] as String,
                  style: TextStyle(fontSize: 13, color: AppColors.gris600),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: beneficios.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: AppColors.gris200),
                  itemBuilder: (context, index) {
                    final beneficio = beneficios[index];
                    final isCashback = beneficio['benefit_type'] == 'cashback';
                    final hcCost = (beneficio['hc_cost'] as num?)?.toInt();
                    final hcReward = (beneficio['hc_reward'] as num?)?.toInt();
                    final hcLabel = isCashback ? '+$hcReward HC' : '$hcCost HC';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.card_giftcard,
                        color: AppColors.primarioRojo,
                      ),
                      title: Text(
                        beneficio['title'] as String? ?? 'Beneficio',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primarioNegro,
                        ),
                      ),
                      subtitle: Text(hcLabel),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _openBeneficio(beneficio);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Mapa de beneficios'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading || _businessIcon == null || _meIcon == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primarioRojo),
      );
    }

    if (_businesses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Ningún beneficio activo tiene ubicación registrada todavía.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gris600),
          ),
        ),
      );
    }

    final userLocation = _userLocation;
    final center = userLocation != null
        ? LatLng(userLocation.latitude, userLocation.longitude)
        : LatLng(
            (_businesses.first['latitude'] as num).toDouble(),
            (_businesses.first['longitude'] as num).toDouble(),
          );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: userLocation != null ? 13 : 11,
          ),
          mapType: _mapType,
          onTap: (_) => setState(() => _selected = null),
          markers: {
            for (final business in _businesses)
              Marker(
                markerId: MarkerId(business['key'] as String),
                position: LatLng(
                  (business['latitude'] as num).toDouble(),
                  (business['longitude'] as num).toDouble(),
                ),
                icon: _businessIcon!,
                onTap: () => setState(() => _selected = business),
              ),
            if (userLocation != null)
              Marker(
                markerId: const MarkerId('me'),
                position: center,
                icon: _meIcon!,
                anchor: const Offset(0.5, 0.5),
                zIndexInt: 2,
              ),
          },
        ),
        Positioned(
          top: 12,
          right: 12,
          child: MapTypeButton(
            selected: _mapType,
            onSelected: (type) => setState(() => _mapType = type),
          ),
        ),
        if (_selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: FloatingLocationCard(
              item: {'title': _businessCardTitle(_selected!)},
              onDismiss: () => setState(() => _selected = null),
              onTapDetail: () => _showBusinessBeneficios(_selected!),
            ),
          ),
      ],
    );
  }

  String _businessCardTitle(Map<String, dynamic> business) {
    final name = business['company_name'] as String;
    final count = (business['beneficios'] as List).length;
    return count > 1 ? '$name · $count beneficios' : name;
  }
}

class _HistorialTab extends StatelessWidget {
  const _HistorialTab();

  static const _typeLabels = {
    'voto': 'Voto en iniciativa',
    'checkin': 'Check-in en iniciativa',
    'redemption_spend': 'Canje de beneficio',
    'redemption_cashback': 'Cashback',
    'ajuste': 'Ajuste',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: WalletService.instance.transactionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primarioRojo),
          );
        }

        final transactions = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            _IniciativasAhorroBanner(
              onTap: () =>
                  Navigator.of(context).pushNamed('/iniciativas-ahorro'),
            ),
            const SizedBox(height: 20),
            Text(
              'Historial',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primarioNegro,
              ),
            ),
            const SizedBox(height: 8),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Aún no tienes movimientos de HC.',
                    style: TextStyle(color: AppColors.gris600),
                  ),
                ),
              )
            else
              ..._historyRows(transactions),
          ],
        );
      },
    );
  }

  List<Widget> _historyRows(List<Map<String, dynamic>> transactions) {
    return [
      for (var index = 0; index < transactions.length; index++) ...[
        if (index != 0) const Divider(height: 1),
        Builder(
          builder: (context) {
            final t = transactions[index];
            final amount = (t['amount'] as num?)?.toInt() ?? 0;
            final type = t['type'] as String? ?? '';
            final createdAt = DateTime.tryParse(
              t['created_at'] as String? ?? '',
            );
            final isPositive = amount >= 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isPositive
                        ? Icons.arrow_circle_up
                        : Icons.arrow_circle_down,
                    color: isPositive
                        ? AppColors.secundarioVerde
                        : AppColors.primarioRojo,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _typeLabels[type] ?? type,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primarioNegro,
                          ),
                        ),
                        if (createdAt != null)
                          Text(
                            '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.gris600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${isPositive ? '+' : ''}$amount HC',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isPositive
                          ? AppColors.secundarioVerde
                          : AppColors.primarioRojo,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ];
  }
}

/// Banner "Iniciativas de ahorro" (mismo estilo del mockup: fondo
/// negro, texto y flecha), atajo a la pantalla ya existente.
class _IniciativasAhorroBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _IniciativasAhorroBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primarioNegro,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Iniciativas de ahorro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ahorra con propósito: construye, estudia o adquiere '
                    'lo que sueñas con metas claras y motivación.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_forward,
                color: AppColors.primarioNegro,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingTab extends StatefulWidget {
  const _RankingTab();

  @override
  State<_RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<_RankingTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _ranking = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final ranking = await RankingService.instance.fetchTopByCheckins();
      if (mounted) setState(() => _ranking = ranking);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primarioRojo),
      );
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    final myIndex = _ranking.indexWhere((r) => r['id'] == userId);
    final top = _ranking.take(20).toList();
    final showMyPosition = myIndex >= 20;

    if (top.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primarioRojo,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 56,
              color: AppColors.gris400,
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no hay check-ins registrados.\nSé el primero en aparecer aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gris600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primarioRojo,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: top.length + (showMyPosition ? 2 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index < top.length) {
            final entry = top[index];
            return _RankingRow(
              position: index + 1,
              entry: entry,
              isMe: entry['id'] == userId,
            );
          }
          if (index == top.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppColors.gris300),
            );
          }
          return _RankingRow(
            position: myIndex + 1,
            entry: _ranking[myIndex],
            isMe: true,
          );
        },
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int position;
  final Map<String, dynamic> entry;
  final bool isMe;

  const _RankingRow({
    required this.position,
    required this.entry,
    required this.isMe,
  });

  static const _medalColors = {
    1: Color(0xFFFFC24B),
    2: Color(0xFFB0B7C3),
    3: Color(0xFFCD7F32),
  };

  @override
  Widget build(BuildContext context) {
    final fullName = entry['full_name'] as String? ?? 'Usuario HeartCoin';
    final avatarUrl = entry['avatar_url'] as String?;
    final checkinCount = entry['checkin_count'] as int? ?? 0;
    final medalColor = _medalColors[position];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.rojoClaro1.withValues(alpha: 0.12)
            : AppColors.primarioBlanco,
        borderRadius: BorderRadius.circular(14),
        border: isMe
            ? Border.all(color: AppColors.primarioRojo, width: 1.2)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: medalColor != null
                ? Icon(Icons.emoji_events, color: medalColor, size: 22)
                : Text(
                    '$position',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gris600,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.gris200,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(Icons.person, size: 18, color: AppColors.gris600)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? '$fullName (Tú)' : fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primarioNegro,
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.qr_code_scanner, size: 14, color: AppColors.gris600),
              const SizedBox(width: 4),
              Text(
                '$checkinCount',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarioNegro,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
