import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla si la app puede usar la ubicación del dispositivo (para
/// ordenar por "Cercanos" en Explorar), persistido en el dispositivo.
class LocationPreferenceController {
  LocationPreferenceController._();
  static final LocationPreferenceController instance =
      LocationPreferenceController._();

  static const _prefsKey = 'location_preference_enabled';

  final ValueNotifier<bool> enabled = ValueNotifier(true);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_prefsKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
