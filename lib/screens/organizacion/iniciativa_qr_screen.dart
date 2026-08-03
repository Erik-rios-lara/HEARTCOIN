import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_colors.dart';

/// Pantalla que muestra el código QR de check-in de una iniciativa,
/// para que la organización lo proyecte o imprima en el evento.
class IniciativaQrScreen extends StatelessWidget {
  final String iniciativaId;
  final String iniciativaTitle;

  const IniciativaQrScreen({
    super.key,
    required this.iniciativaId,
    required this.iniciativaTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Código QR de check-in'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              iniciativaTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primarioNegro,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primarioBlanco,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: iniciativaId,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Muestra este código a los participantes durante el evento '
              'para que puedan hacer check-in con su ubicación.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.gris600),
            ),
          ],
        ),
      ),
    );
  }
}
