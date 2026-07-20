import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckinException implements Exception {
  final String message;
  CheckinException(this.message);

  @override
  String toString() => message;
}

class CheckinService {
  CheckinService._();
  static final CheckinService instance = CheckinService._();
  SupabaseClient get _client => Supabase.instance.client;

  Future<bool> hasCheckedIn(String iniciativaId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final result = await _client
        .from('iniciativa_checkins')
        .select('iniciativa_id')
        .eq('iniciativa_id', iniciativaId)
        .eq('user_id', userId)
        .maybeSingle();
    return result != null;
  }

  Future<void> checkIn(String iniciativaId) async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        throw CheckinException(
          'Se necesita permiso de ubicación para hacer check-in.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw CheckinException('Permiso de ubicación denegado permanentemente.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    try {
      await _client.rpc(
        'checkin_iniciativa',
        params: {
          'p_iniciativa_id': iniciativaId,
          'p_lat': position.latitude,
          'p_lng': position.longitude,
        },
      );
    } on PostgrestException catch (e) {
      throw CheckinException(_mapError(e.message));
    }
  }

  String _mapError(String raw) {
    if (raw.contains('duplicate key') ||
        raw.contains('iniciativa_checkins_pkey')) {
      return 'Ya hiciste check-in en esta iniciativa.';
    }
    if (raw.contains('fuera_de_horario')) {
      return 'El check-in solo está disponible durante el horario del evento.';
    }
    if (raw.contains('fuera_de_rango')) {
      return 'Estás demasiado lejos del lugar del evento para hacer check-in.';
    }
    if (raw.contains('sin_ubicacion_registrada')) {
      return 'Esta iniciativa no tiene una ubicación registrada.';
    }
    if (raw.contains('sin_fecha_evento')) {
      return 'Esta iniciativa no tiene una fecha de evento definida.';
    }
    if (raw.contains('metodo_no_es_qr')) {
      return 'Esta iniciativa no usa verificación por QR.';
    }
    if (raw.contains('iniciativa_no_encontrada')) {
      return 'No se encontró la iniciativa.';
    }
    return 'No se pudo completar el check-in. Intenta de nuevo.';
  }
}
