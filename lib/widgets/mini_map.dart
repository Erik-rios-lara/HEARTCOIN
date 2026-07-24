import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../screens/location_map_screen.dart';
import '../theme/app_colors.dart';
import 'map_dark_style.dart';
import 'map_marker_icons.dart';

/// Mapa pequeño y no interactivo (Google Maps) con un solo marcador.
/// Al tocarlo abre LocationMapScreen a pantalla completa.
class MiniMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? label;
  final double height;

  /// Estilo de mapa oscuro (Google Maps) en vez del claro por defecto.
  final bool dark;

  /// Otros beneficios/servicios del mismo tipo, mostrados en el mapa a
  /// pantalla completa (no en esta vista previa pequeña).
  final List<Map<String, dynamic>> otherLocations;
  final ValueChanged<Map<String, dynamic>>? onTapOtherLocation;

  const MiniMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label,
    this.height = 160,
    this.dark = false,
    this.otherLocations = const [],
    this.onTapOtherLocation,
  });

  @override
  State<MiniMap> createState() => _MiniMapState();
}

class _MiniMapState extends State<MiniMap> {
  BitmapDescriptor? _icon;

  @override
  void initState() {
    super.initState();
    _loadIcon();
  }

  Future<void> _loadIcon() async {
    final icon = await heartPinBitmap(
      color: widget.dark ? Colors.white : AppColors.primarioRojo,
      heartColor: widget.dark ? AppColors.primarioNegro : Colors.white,
    );
    if (mounted) setState(() => _icon = icon);
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.latitude, widget.longitude);
    final icon = _icon;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LocationMapScreen(
            latitude: widget.latitude,
            longitude: widget.longitude,
            label: widget.label,
            dark: widget.dark,
            otherLocations: widget.otherLocations,
            onTapOtherLocation: widget.onTapOtherLocation,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: widget.height,
          child: icon == null
              ? Container(
                  color: AppColors.gris200,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primarioRojo,
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: point,
                    zoom: 15,
                  ),
                  style: widget.dark ? mapDarkStyleJson : null,
                  markers: {
                    Marker(
                      markerId: const MarkerId('main'),
                      position: point,
                      icon: icon,
                    ),
                  },
                  zoomControlsEnabled: false,
                  zoomGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  liteModeEnabled: false,
                ),
        ),
      ),
    );
  }
}
