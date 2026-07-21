import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pin de mapa con la forma de gota clásica y un corazón blanco al
/// centro, para marcar negocios/beneficios con la identidad de marca
/// de HeartCoin en vez de un ícono genérico.
class HeartMapPin extends StatelessWidget {
  final double size;
  final Color color;

  const HeartMapPin({
    super.key,
    this.size = 32,
    this.color = AppColors.primarioRojo,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.location_on, color: color, size: size),
          Padding(
            padding: EdgeInsets.only(bottom: size * 0.26),
            child: Icon(Icons.favorite, color: Colors.white, size: size * 0.34),
          ),
        ],
      ),
    );
  }
}
