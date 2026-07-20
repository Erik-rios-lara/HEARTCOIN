import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/checkin_service.dart';
import '../theme/app_colors.dart';

/// Escaneo de QR para hacer check-in en una iniciativa específica.
/// El QR escaneado debe contener el mismo id que [iniciativaId].
class CheckinScannerScreen extends StatefulWidget {
  final String iniciativaId;
  final String iniciativaTitle;

  const CheckinScannerScreen({
    super.key,
    required this.iniciativaId,
    required this.iniciativaTitle,
  });

  @override
  State<CheckinScannerScreen> createState() => _CheckinScannerScreenState();
}

class _CheckinScannerScreenState extends State<CheckinScannerScreen> {
  final _controller = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    if (code.trim() != widget.iniciativaId) {
      _showMessage('Este QR no corresponde a esta iniciativa.', isError: true);
      return;
    }

    setState(() => _processing = true);
    await _controller.stop();

    try {
      await CheckinService.instance.checkIn(widget.iniciativaId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _showMessage('¡Check-in realizado con éxito!');
    } on CheckinException catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
      setState(() => _processing = false);
      await _controller.start();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Ocurrió un error al hacer check-in.', isError: true);
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
        title: Text('Check-in: ${widget.iniciativaTitle}'),
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
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Text(
              'Apunta la cámara al código QR del evento',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
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
