import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/location_preference_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/iniciativa_widgets.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _categories = ['Voluntariado', 'Crowdfunding', 'Social', 'Ahorro'];

  static const _categoryColors = {
    'Voluntariado': Color(0xFFEC324C),
    'Crowdfunding': Color(0xFFFF8C42),
    'Social': Color(0xFF4A7CFF),
    'Ahorro': Color(0xFF42B883),
  };

  static const _categoryIcons = {
    'Voluntariado': Icons.volunteer_activism,
    'Crowdfunding': Icons.savings,
    'Social': Icons.groups,
    'Ahorro': Icons.account_balance_wallet,
  };

  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();

  String? _locationLabel;
  Position? _userPosition;
  Map<String, int> _categoryCounts = {};

  String? _selectedCategory;
  IniciativaSortOption _sort = IniciativaSortOption.reciente;

  bool _isLoading = true;
  List<Map<String, dynamic>> _iniciativas = [];

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _loadCategoryCounts();
    _loadIniciativas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    if (!LocationPreferenceController.instance.enabled.value) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final placemark = placemarks.isNotEmpty ? placemarks.first : null;
      final label = [
        placemark?.locality,
        placemark?.country,
      ].where((p) => p != null && p.isNotEmpty).join(', ');

      if (!mounted) return;
      setState(() {
        _userPosition = position;
        _locationLabel = label.isNotEmpty ? label : null;
      });
    } catch (_) {
      // Sin ubicación disponible: "Cercanos" simplemente no se podrá calcular.
    }
  }

  Future<void> _loadCategoryCounts() async {
    try {
      final counts = <String, int>{};
      for (final category in _categories) {
        final response = await _client
            .from('iniciativas')
            .select('id')
            .eq('status', 'activa')
            .eq('category', category)
            .count();
        counts[category] = response.count;
      }
      if (!mounted) return;
      setState(() => _categoryCounts = counts);
    } catch (_) {
      // Sin conteos disponibles: las tarjetas simplemente muestran 0.
    }
  }

  Future<void> _loadIniciativas() async {
    setState(() => _isLoading = true);
    try {
      var query = _client.from('iniciativas').select().eq('status', 'activa');

      final category = _selectedCategory;
      if (category != null) {
        query = query.eq('category', category);
      }
      final search = _searchController.text.trim();
      if (search.isNotEmpty) {
        query = query.ilike('title', '%$search%');
      }

      final rows = await query;
      final list = (rows as List).cast<Map<String, dynamic>>();
      _applySort(list);

      if (!mounted) return;
      setState(() => _iniciativas = list);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySort(List<Map<String, dynamic>> list) {
    switch (_sort) {
      case IniciativaSortOption.popular:
        list.sort(
          (a, b) => ((b['votes_count'] as num?) ?? 0).compareTo(
            (a['votes_count'] as num?) ?? 0,
          ),
        );
        break;
      case IniciativaSortOption.reciente:
        list.sort(
          (a, b) => (b['created_at'] as String? ?? '').compareTo(
            a['created_at'] as String? ?? '',
          ),
        );
        break;
      case IniciativaSortOption.cercanos:
        final position = _userPosition;
        if (position == null) break;
        list.sort(
          (a, b) =>
              _distanceTo(position, a).compareTo(_distanceTo(position, b)),
        );
        break;
    }
  }

  double _distanceTo(Position from, Map<String, dynamic> iniciativa) {
    final lat = (iniciativa['latitude'] as num?)?.toDouble();
    final lng = (iniciativa['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return double.infinity;
    return Geolocator.distanceBetween(from.latitude, from.longitude, lat, lng);
  }

  void _onCategorySelected(String? category) {
    setState(
      () => _selectedCategory = _selectedCategory == category ? null : category,
    );
    _loadIniciativas();
  }

  void _onSortSelected(IniciativaSortOption sort) {
    setState(() => _sort = sort);
    _applySort(_iniciativas);
    setState(() {});
  }

  void _openFiltersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primarioBlanco,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
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
              IniciativaSortChips(
                selected: _sort,
                onSelected: (s) {
                  Navigator.of(sheetContext).pop();
                  _onSortSelected(s);
                },
              ),
              SizedBox(height: MediaQuery.of(sheetContext).padding.bottom + 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primarioRojo,
          onRefresh: _loadIniciativas,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: AppColors.primarioNegro,
                      size: 26,
                    ),
                  ),
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primarioNegro,
                    size: 26,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Heart Coin',
                style: TextStyle(fontSize: 12, color: AppColors.gris600),
              ),
              const Text(
                'Explorar',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarioNegro,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primarioBlanco,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.gris300),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _loadIniciativas(),
                        decoration: InputDecoration(
                          hintText: 'Buscar iniciativas...',
                          hintStyle: TextStyle(color: AppColors.gris600),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppColors.gris600,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primarioRojo,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: _openFiltersSheet,
                      icon: const Icon(Icons.tune, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: [
                  for (final category in _categories)
                    _CategoryCard(
                      label: category,
                      count: _categoryCounts[category] ?? 0,
                      color: _categoryColors[category]!,
                      icon: _categoryIcons[category]!,
                      selected: _selectedCategory == category,
                      onTap: () => _onCategorySelected(category),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              const _DecideBanner(),
              const SizedBox(height: 20),

              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.primarioRojo,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _locationLabel != null
                        ? 'Cerca de ti · $_locationLabel'
                        : 'Cerca de ti',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarioNegro,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 36,
                child: IniciativaSortChips(
                  selected: _sort,
                  onSelected: _onSortSelected,
                  scrollable: true,
                ),
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primarioRojo,
                    ),
                  ),
                )
              else if (_iniciativas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No hay iniciativas que coincidan con tu búsqueda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.gris600),
                    ),
                  ),
                )
              else
                ..._iniciativas.map(
                  (iniciativa) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IniciativaCard(iniciativa: iniciativa),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: AppColors.primarioNegro, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -6,
              bottom: -6,
              child: Icon(
                icon,
                size: 44,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count iniciativas',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DecideBanner extends StatelessWidget {
  const _DecideBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  'Decide lo que Importa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Haz oír tu voz y vota por las iniciativas que harán la diferencia.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.rotate(
                angle: -0.25,
                child: const Icon(
                  Icons.thumb_up_alt,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              Positioned(
                right: -14,
                top: 14,
                child: Transform.rotate(
                  angle: 0.25,
                  child: const Icon(
                    Icons.thumb_up_alt,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
