import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/app_colors.dart';

/// Botón flotante con menú para cambiar el tipo de mapa (Normal /
/// Satélite / Terreno / Híbrido), reutilizado en las pantallas de
/// mapa a pantalla completa.
class MapTypeButton extends StatelessWidget {
  final MapType selected;
  final ValueChanged<MapType> onSelected;

  const MapTypeButton({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const _labels = {
    MapType.normal: 'Normal',
    MapType.satellite: 'Satélite',
    MapType.terrain: 'Terreno',
    MapType.hybrid: 'Híbrido',
  };

  static const _icons = {
    MapType.normal: Icons.map_outlined,
    MapType.satellite: Icons.satellite_alt_outlined,
    MapType.terrain: Icons.terrain_outlined,
    MapType.hybrid: Icons.layers_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MapType>(
      initialValue: selected,
      onSelected: onSelected,
      tooltip: 'Tipo de mapa',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => _labels.entries.map((entry) {
        final isSelected = entry.key == selected;
        return PopupMenuItem(
          value: entry.key,
          child: Row(
            children: [
              Icon(
                _icons[entry.key],
                size: 18,
                color: isSelected ? AppColors.primarioRojo : AppColors.gris700,
              ),
              const SizedBox(width: 10),
              Text(
                entry.value,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primarioRojo
                      : AppColors.primarioNegro,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primarioBlanco,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(_icons[selected], color: AppColors.primarioNegro, size: 20),
      ),
    );
  }
}
