import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/beneficio_service.dart';
import '../services/servicio_service.dart';
import '../theme/app_colors.dart';

/// Escaneo del QR de un beneficio (mostrado por la empresa en su
/// local) para canjearlo con HeartCoins.
class BeneficioScannerScreen extends StatefulWidget {
  const BeneficioScannerScreen({super.key});

  @override
  State<BeneficioScannerScreen> createState() => _BeneficioScannerScreenState();
}

class _BeneficioScannerScreenState extends State<BeneficioScannerScreen> {
  final _controller = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (code == null) return;

    setState(() => _processing = true);
    await _controller.stop();

    try {
      final beneficio = await BeneficioService.instance.fetchBeneficio(code);
      if (beneficio != null) {
        await BeneficioService.instance.redeem(code);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        _showMessage('¡Canjeaste "${beneficio['title']}" con éxito!');
        return;
      }

      final servicio = await ServicioService.instance.fetchServicio(code);
      if (servicio != null) {
        await ServicioService.instance.redeem(code);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        _showMessage('¡Canjeaste "${servicio['title']}" con éxito!');
        return;
      }

      _showMessage(
        'Este código no corresponde a un beneficio o servicio.',
        isError: true,
      );
      setState(() => _processing = false);
      await _controller.start();
    } on RedeemBeneficioException catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
      setState(() => _processing = false);
      await _controller.start();
    } on RedeemServicioException catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
      setState(() => _processing = false);
      await _controller.start();
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Ocurrió un error al canjear. Intenta de nuevo.',
        isError: true,
      );
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.primarioRojo
            : AppColors.secundarioVerde,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Canjear'),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primarioRojo, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primarioRojo),
              ),
            ),
          const Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Text(
              'Apunta la cámara al código QR del beneficio o servicio',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
