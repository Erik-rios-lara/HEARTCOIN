import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../screens/location_map_screen.dart';
import '../theme/app_colors.dart';

/// Mapa pequeño y no interactivo (OpenStreetMap, sin API key) con un solo
/// marcador. Al tocarlo abre LocationMapScreen a pantalla completa.
class MiniMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? label;
  final double height;

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
    this.otherLocations = const [],
    this.onTapOtherLocation,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LocationMapScreen(
            latitude: latitude,
            longitude: longitude,
            label: label,
            otherLocations: otherLocations,
            onTapOtherLocation: onTapOtherLocation,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.theoriginallab.heartcoin',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 34,
                        height: 34,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primarioRojo,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const _OsmAttribution(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 4,
      bottom: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        color: Colors.white.withValues(alpha: 0.7),
        child: const Text(
          '© OpenStreetMap',
          style: TextStyle(fontSize: 9, color: Colors.black87),
        ),
      ),
    );
  }
}
