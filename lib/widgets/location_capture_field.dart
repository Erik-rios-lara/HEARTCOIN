import 'package:flutter/material.dart';

import '../services/current_location.dart';
import '../theme/app_colors.dart';

/// Botón "Usar mi ubicación actual" reutilizado por los formularios de
/// creación de beneficios y servicios. Notifica el resultado (o `null`
/// si se limpia) vía [onChanged].
class LocationCaptureField extends StatefulWidget {
  final ValueChanged<LocationCaptureResult?> onChanged;

  const LocationCaptureField({super.key, required this.onChanged});

  @override
  State<LocationCaptureField> createState() => _LocationCaptureFieldState();
}

class _LocationCaptureFieldState extends State<LocationCaptureField> {
  bool _isFetching = false;
  LocationCaptureResult? _result;

  Future<void> _capture() async {
    setState(() => _isFetching = true);
    try {
      final result = await captureCurrentLocation();
      if (!mounted) return;
      setState(() => _result = result);
      widget.onChanged(result);
    } on LocationPermissionDeniedException catch (e) {
      _showMessage(e.toString());
    } on LocationServiceDisabledException catch (e) {
      _showMessage(e.toString());
    } catch (_) {
      _showMessage('No se pudo obtener tu ubicación.');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  void _clear() {
    setState(() => _result = null);
    widget.onChanged(null);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primarioBlanco,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gris300),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: AppColors.primarioRojo, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _result!.label ?? 'Ubicación actual',
                style: TextStyle(fontSize: 13, color: AppColors.primarioNegro),
              ),
            ),
            GestureDetector(
              onTap: _clear,
              child: Icon(Icons.close, size: 18, color: AppColors.gris600),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _isFetching ? null : _capture,
      icon: _isFetching
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location, size: 18),
      label: Text(_isFetching ? 'Obteniendo ubicación...' : 'Usar mi ubicación actual'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primarioRojo,
        side: const BorderSide(color: AppColors.primarioRojo),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
