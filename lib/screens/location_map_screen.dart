import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';
import '../widgets/floating_location_card.dart';

/// Mapa a pantalla completa (interactivo) para una ubicación, con
/// opcionalmente otros lugares del mismo tipo (otros beneficios u
/// otros servicios) marcados alrededor.
class LocationMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? label;

  /// Otros beneficios/servicios (mismo tipo que el que se está viendo)
  /// con `latitude`/`longitude`/`title` propios.
  final List<Map<String, dynamic>> otherLocations;
  final ValueChanged<Map<String, dynamic>>? onTapOtherLocation;

  const LocationMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label,
    this.otherLocations = const [],
    this.onTapOtherLocation,
  });

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  Map<String, dynamic>? _selected;

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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: Text(widget.label ?? 'Ubicación'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15,
              onTap: (_, _) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.theoriginallab.heartcoin',
              ),
              MarkerLayer(
                markers: [
                  for (final item in others)
                    Marker(
                      point: LatLng(
                        (item['latitude'] as num).toDouble(),
                        (item['longitude'] as num).toDouble(),
                      ),
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = item),
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.secundarioAzul,
                          size: 32,
                        ),
                      ),
                    ),
                  Marker(
                    point: point,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.primarioRojo,
                      size: 44,
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
