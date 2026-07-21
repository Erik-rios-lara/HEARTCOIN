import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/beneficio_service.dart';
import '../services/current_location.dart';
import '../services/location_preference_controller.dart';
import '../services/ranking_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_colors.dart';
import '../widgets/floating_location_card.dart';
import '../widgets/heart_map_pin.dart';
import '../widgets/iniciativa_widgets.dart' show AppChip;
import 'beneficio_detail_screen.dart';
import 'beneficio_scanner_screen.dart';

/// Billetera de HeartCoin del usuario: balance real, beneficios
/// disponibles para canjear (vía QR) e historial de movimientos.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Mi billetera'),
      ),
      body: Column(
        children: [
          StreamBuilder<Map<String, dynamic>?>(
            stream: WalletService.instance.profileStream(),
            builder: (context, snapshot) {
              final balance =
                  (snapshot.data?['hc_balance'] as num?)?.toInt() ?? 0;
              return _BalanceCard(
                balance: balance,
                onScan: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BeneficioScannerScreen(),
                  ),
                ),
              );
            },
          ),
          Container(
            color: AppColors.primarioBlanco,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primarioRojo,
              unselectedLabelColor: AppColors.gris600,
              indicatorColor: AppColors.primarioRojo,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Beneficios'),
                Tab(text: 'Mapa'),
                Tab(text: 'Historial'),
                Tab(text: 'Ranking'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _BeneficiosTab(),
                _BeneficiosMapaTab(),
                _HistorialTab(),
                _RankingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int balance;
  final VoidCallback onScan;

  const _BalanceCard({required this.balance, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primarioRojo, AppColors.rojoOscuro1],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance de HeartCoins',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.toll, color: Colors.white, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      '$balance HC',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Canjear'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BeneficiosTab extends StatefulWidget {
  const _BeneficiosTab();

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

  bool _sortCercanos = false;
  LocationCaptureResult? _userLocation;

  @override
  void initState() {
    super.initState();
    _loadLocation();
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

        final beneficios = (snapshot.data ?? [])
            .where((b) => b['status'] == 'activo')
            .toList();
        if (_sortCercanos) {
          beneficios.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  AppChip(
                    label: 'Recientes',
                    selected: !_sortCercanos,
                    onTap: () => setState(() => _sortCercanos = false),
                  ),
                  const SizedBox(width: 8),
                  AppChip(
                    label: 'Cercanos',
                    selected: _sortCercanos,
                    onTap: () => setState(() => _sortCercanos = true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: beneficios.isEmpty
                  ? Center(
                      child: Text(
                        'No hay beneficios disponibles por ahora.',
                        style: TextStyle(color: AppColors.gris600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: beneficios.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final beneficio = beneficios[index];
                        final benefitType =
                            beneficio['benefit_type'] as String? ?? 'otro';
                        final title =
                            beneficio['title'] as String? ?? 'Beneficio';
                        final companyName =
                            beneficio['company_name'] as String?;
                        final description = beneficio['description'] as String?;
                        final hcCost = (beneficio['hc_cost'] as num?)?.toInt();
                        final hcReward = (beneficio['hc_reward'] as num?)
                            ?.toInt();
                        final hcLabel = benefitType == 'cashback'
                            ? '+$hcReward HC'
                            : '$hcCost HC';
                        final location = beneficio['location'] as String?;

                        return Material(
                          color: AppColors.primarioBlanco,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BeneficioDetailScreen(beneficio: beneficio),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _typeIcons[benefitType] ??
                                            Icons.card_giftcard,
                                        size: 16,
                                        color: AppColors.primarioRojo,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _typeLabels[benefitType] ?? benefitType,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primarioRojo,
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                  const SizedBox(height: 10),
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primarioNegro,
                                    ),
                                  ),
                                  if (companyName != null &&
                                      companyName.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      companyName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.gris700,
                                      ),
                                    ),
                                  ],
                                  if (location != null &&
                                      location.isNotEmpty) ...[
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
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.gris600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (description != null &&
                                      description.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.gris600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Mapa con todos los beneficios activos que tienen ubicación
/// registrada, centrado en la posición actual del usuario si está
/// disponible.
class _BeneficiosMapaTab extends StatefulWidget {
  const _BeneficiosMapaTab();

  @override
  State<_BeneficiosMapaTab> createState() => _BeneficiosMapaTabState();
}

class _BeneficiosMapaTabState extends State<_BeneficiosMapaTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _businesses = [];
  LocationCaptureResult? _userLocation;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadBeneficios(), _loadLocation()]);
    if (mounted) setState(() => _isLoading = false);
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
    if (_isLoading) {
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
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: userLocation != null ? 13 : 11,
            onTap: (_, _) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.heartcoin',
            ),
            MarkerLayer(
              markers: [
                for (final business in _businesses)
                  Marker(
                    point: LatLng(
                      (business['latitude'] as num).toDouble(),
                      (business['longitude'] as num).toDouble(),
                    ),
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = business),
                      child: const HeartMapPin(size: 36),
                    ),
                  ),
                if (userLocation != null)
                  Marker(
                    point: center,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primarioRojo,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: Colors.white.withValues(alpha: 0.8),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 11, color: Colors.black87),
            ),
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
        if (transactions.isEmpty) {
          return Center(
            child: Text(
              'Aún no tienes movimientos de HC.',
              style: TextStyle(color: AppColors.gris600),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: transactions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
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
        );
      },
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
