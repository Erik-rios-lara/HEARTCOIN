import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_colors.dart';

/// Pantalla que muestra el código QR de canje de un servicio, para
/// que la empresa lo comparta con sus clientes.
class ServicioQrScreen extends StatelessWidget {
  final String servicioId;
  final String servicioTitle;

  const ServicioQrScreen({
    super.key,
    required this.servicioId,
    required this.servicioTitle,
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
              servicioTitle,
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
                data: servicioId,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Muestra este código a tus clientes para que puedan '
              'canjear este servicio con sus HeartCoins.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.gris600),
            ),
          ],
        ),
      ),
    );
  }
}
