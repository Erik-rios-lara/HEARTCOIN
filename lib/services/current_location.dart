import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationCaptureResult {
  final String? label;
  final double latitude;
  final double longitude;

  const LocationCaptureResult({
    required this.label,
    required this.latitude,
    required this.longitude,
  });
}

class LocationPermissionDeniedException implements Exception {
  @override
  String toString() => 'Permiso de ubicación denegado.';
}

class LocationServiceDisabledException implements Exception {
  @override
  String toString() => 'Activa el GPS para continuar.';
}

/// Permiso → posición GPS → geocoding inverso a una etiqueta legible
/// ("Ciudad, Estado, País"). Mismo flujo que ya usaban por separado
/// create_post_screen.dart y explore_screen.dart.
Future<LocationCaptureResult> captureCurrentLocation() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw LocationPermissionDeniedException();
  }

  if (!await Geolocator.isLocationServiceEnabled()) {
    throw LocationServiceDisabledException();
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
  );

  String? label;
  try {
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    final placemark = placemarks.isNotEmpty ? placemarks.first : null;
    final parts = [
      placemark?.locality,
      placemark?.administrativeArea,
      placemark?.country,
    ].where((part) => part != null && part.isNotEmpty).join(', ');
    label = parts.isNotEmpty ? parts : null;
  } catch (_) {
    // Sin geocoding inverso disponible: se guardan igual las coordenadas.
  }

  return LocationCaptureResult(
    label: label,
    latitude: position.latitude,
    longitude: position.longitude,
  );
}
