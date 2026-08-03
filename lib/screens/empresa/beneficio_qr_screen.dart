import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_colors.dart';

/// Pantalla que muestra el código QR de canje de un beneficio, para
/// que la empresa lo proyecte o imprima en su local.
class BeneficioQrScreen extends StatelessWidget {
  final String beneficioId;
  final String beneficioTitle;

  const BeneficioQrScreen({
    super.key,
    required this.beneficioId,
    required this.beneficioTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Código QR de canje'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              beneficioTitle,
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
                data: beneficioId,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Muestra este código a tus clientes para que puedan '
              'canjear este beneficio con sus HeartCoins.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.gris600),
            ),
          ],
        ),
      ),
    );
  }
}
