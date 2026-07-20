import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla el tamaño de texto global de la app (accesibilidad),
/// persistido en el dispositivo.
class TextScaleController {
  TextScaleController._();
  static final TextScaleController instance = TextScaleController._();

  static const _prefsKey = 'text_scale_factor';
  static const double min = 0.85;
  static const double max = 1.3;
  static const double step = 0.05;

  final ValueNotifier<double> scale = ValueNotifier(1.0);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    scale.value = prefs.getDouble(_prefsKey) ?? 1.0;
  }

  Future<void> setScale(double value) async {
    final clamped = value.clamp(min, max);
    scale.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, clamped);
  }

  void increase() => setScale(scale.value + step);
  void decrease() => setScale(scale.value - step);
  void reset() => setScale(1.0);
}
