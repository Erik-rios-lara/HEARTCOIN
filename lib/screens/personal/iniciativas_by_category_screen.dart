import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/iniciativa_widgets.dart';

/// Listado de iniciativas de una sola categoría (misma tabla que
/// Explorar, filtrada de forma fija). Reutilizado por Ahorro y Social.
class IniciativasByCategoryScreen extends StatefulWidget {
  final String category;
  final String title;
  final String searchHint;
  final String emptyMessage;

  /// Si se provee, muestra un botón flotante "+" que abre esta pantalla
  /// de creación; debe devolver `true` si se creó algo, para refrescar.
  final Future<bool?> Function(BuildContext context)? onCreate;

  const IniciativasByCategoryScreen({
    super.key,
    required this.category,
    required this.title,
    required this.searchHint,
    required this.emptyMessage,
    this.onCreate,
  });

  @override
  State<IniciativasByCategoryScreen> createState() =>
      _IniciativasByCategoryScreenState();
}

class _IniciativasByCategoryScreenState
    extends State<IniciativasByCategoryScreen> {
  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();

  IniciativaSortOption _sort = IniciativaSortOption.reciente;

  Position? _userPosition;
  String? _locationLabel;

  bool _isLoading = true;
  List<Map<String, dynamic>> _iniciativas = [];

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
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
      // Sin ubicación disponible: "Cercanos" cae en orden reciente.
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      var query = _client
          .from('iniciativas')
          .select()
          .eq('category', widget.category)
          .eq('status', 'activa');

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

  void _onSortSelected(IniciativaSortOption sort) {
    setState(() => _sort = sort);
    _applySort(_iniciativas);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: Text(widget.title),
      ),
      floatingActionButton: widget.onCreate == null
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final created = await widget.onCreate!(context);
                if (created == true) _load();
              },
              backgroundColor: AppColors.primarioRojo,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: RefreshIndicator(
        color: AppColors.primarioRojo,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.primarioBlanco,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gris300),
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: TextStyle(color: AppColors.gris600),
                  prefixIcon: Icon(Icons.search, color: AppColors.gris600),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 36,
              child: IniciativaSortChips(
                selected: _sort,
                onSelected: _onSortSelected,
                scrollable: true,
              ),
            ),
            const SizedBox(height: 16),

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
                    widget.emptyMessage,
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
