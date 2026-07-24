import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';
import '../widgets/floating_location_card.dart';
import '../widgets/map_dark_style.dart';
import '../widgets/map_marker_icons.dart';
import '../widgets/map_type_button.dart';

/// Mapa a pantalla completa (interactivo, Google Maps) para una
/// ubicación, con opcionalmente otros lugares del mismo tipo (otros
/// beneficios u otros servicios) marcados alrededor.
class LocationMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? label;

  /// Estilo de mapa oscuro (Google Maps) en vez del claro por defecto.
  final bool dark;

  /// Otros beneficios/servicios (mismo tipo que el que se está viendo)
  /// con `id`/`latitude`/`longitude`/`title` propios.
  final List<Map<String, dynamic>> otherLocations;
  final ValueChanged<Map<String, dynamic>>? onTapOtherLocation;

  const LocationMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label,
    this.dark = false,
    this.otherLocations = const [],
    this.onTapOtherLocation,
  });

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  Map<String, dynamic>? _selected;
  BitmapDescriptor? _mainIcon;
  BitmapDescriptor? _otherIcon;
  MapType _mapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    final mainColor = widget.dark ? Colors.white : AppColors.primarioRojo;
    final mainHeart = widget.dark ? AppColors.primarioNegro : Colors.white;
    final otherColor = widget.dark ? Colors.white70 : AppColors.secundarioAzul;

    final results = await Future.wait([
      heartPinBitmap(color: mainColor, heartColor: mainHeart, size: 52),
      heartPinBitmap(color: otherColor, heartColor: Colors.white, size: 40),
    ]);
    if (!mounted) return;
    setState(() {
      _mainIcon = results[0];
      _otherIcon = results[1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.latitude, widget.longitude);
    final others = widget.otherLocations
        .where(
          (item) =>
              (item['latitude'] as num?) != null &&
              (item['longitude'] as num?) != null,
        )
        .toList();
    final dark = widget.dark;
    final mainIcon = _mainIcon;
    final otherIcon = _otherIcon;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: dark
            ? AppColors.primarioNegro
            : AppColors.primarioBlanco,
        foregroundColor: dark ? Colors.white : AppColors.primarioNegro,
        elevation: 0,
        title: Text(widget.label ?? 'Ubicación'),
      ),
      body: (mainIcon == null || otherIcon == null)
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: point,
                    zoom: 15,
                  ),
                  mapType: _mapType,
                  style: dark ? mapDarkStyleJson : null,
                  onTap: (_) => setState(() => _selected = null),
                  markers: {
                    Marker(
                      markerId: const MarkerId('main'),
                      position: point,
                      icon: mainIcon,
                    ),
                    for (final item in others)
                      Marker(
                        markerId: MarkerId('other_${item['id']}'),
                        position: LatLng(
                          (item['latitude'] as num).toDouble(),
                          (item['longitude'] as num).toDouble(),
                        ),
                        icon: otherIcon,
                        onTap: () => setState(() => _selected = item),
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
                      item: _selected!,
                      onDismiss: () => setState(() => _selected = null),
                      onTapDetail: () {
                        final item = _selected!;
                        setState(() => _selected = null);
                        widget.onTapOtherLocation?.call(item);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
