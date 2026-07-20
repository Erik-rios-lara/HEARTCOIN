import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Pantalla genérica de "Próximamente" para secciones aún no
/// implementadas. Se reutiliza para varias rutas del drawer,
/// cada una con su propio título vía argumentos de la ruta.
class ComingSoonScreen extends StatelessWidget {
  final String title;

  const ComingSoonScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primarioBlanco,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        elevation: 0,
        foregroundColor: AppColors.primarioNegro,
        title: Text(title),
      ),
      body: Center(
        child: Text(
          'Próximamente',
          style: TextStyle(fontSize: 16, color: AppColors.gris600),
        ),
      ),
    );
  }
}
