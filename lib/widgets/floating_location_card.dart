import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tarjeta flotante minimalista para mostrar sobre un mapa al tocar un
/// pin: título del lugar + botón para ver su detalle + cerrar.
class FloatingLocationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDismiss;
  final VoidCallback onTapDetail;

  const FloatingLocationCard({
    super.key,
    required this.item,
    required this.onDismiss,
    required this.onTapDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarioBlanco,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTapDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              const Icon(
                Icons.location_on,
                color: AppColors.secundarioAzul,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item['title'] as String? ?? 'Sin título',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primarioNegro,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: AppColors.gris600),
              GestureDetector(
                onTap: onDismiss,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 16, color: AppColors.gris600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
