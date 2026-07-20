import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/location_preference_controller.dart';
import '../services/servicio_service.dart';
import '../theme/app_colors.dart';
import '../widgets/iniciativa_widgets.dart';
import 'servicio_detail_screen.dart';

const _serviciosFilter = 'Servicios';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _categories = [
    'Voluntariado',
    'Crowdfunding',
    'Social',
    'Ahorro',
    _serviciosFilter,
  ];

  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();

  String? _selectedCategory;
  IniciativaSortOption _sort = IniciativaSortOption.reciente;

  bool get _isServicios => _selectedCategory == _serviciosFilter;
  List<Map<String, dynamic>> _servicios = [];

  Position? _userPosition;
  String? _locationLabel;

  bool _isLoading = true;
  List<Map<String, dynamic>> _iniciativas = [];

  @override
  void initState() {
    super.initState();
    _loadLocation();
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

  Future<void> _loadServicios() async {
    setState(() => _isLoading = true);
    try {
      final servicios = await ServicioService.instance.fetchActiveServicios(
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _servicios = servicios);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadIniciativas() async {
    if (_isServicios) {
      await _loadServicios();
      return;
    }
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
    setState(() => _selectedCategory = category);
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
                'Filtrar por categoría',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              _CategoryChips(
                categories: _categories,
                selected: _selectedCategory,
                onSelected: (c) {
                  Navigator.of(sheetContext).pop();
                  _onCategorySelected(c);
                },
              ),
              const SizedBox(height: 20),
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
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Explorar'),
      ),
      body: RefreshIndicator(
        color: AppColors.primarioRojo,
        onRefresh: _loadIniciativas,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
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
                        hintText: _isServicios
                            ? 'Buscar servicios...'
                            : 'Buscar iniciativas...',
                        hintStyle: TextStyle(color: AppColors.gris600),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.gris600,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
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
            const SizedBox(height: 16),

            SizedBox(
              height: 36,
              child: _CategoryChips(
                categories: _categories,
                selected: _selectedCategory,
                onSelected: _onCategorySelected,
                scrollable: true,
              ),
            ),
            const SizedBox(height: 12),

            if (!_isServicios) ...[
              SizedBox(
                height: 36,
                child: IniciativaSortChips(
                  selected: _sort,
                  onSelected: _onSortSelected,
                  scrollable: true,
                ),
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
            ] else
              const SizedBox(height: 8),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primarioRojo,
                  ),
                ),
              )
            else if (_isServicios)
              if (_servicios.isEmpty)
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
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final bool scrollable;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final chips = [
      AppChip(
        label: 'Todas',
        selected: selected == null,
        onTap: () => onSelected(null),
      ),
      for (final category in categories)
        AppChip(
          label: category,
          selected: selected == category,
          onTap: () => onSelected(category),
        ),
    ];

    if (!scrollable) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: chips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) => chips[index],
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
