import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Genera el bitmap del pin de marca (gota de mapa + corazón blanco al
/// centro, mismo diseño que `HeartMapPin`) para usarlo como ícono de
/// `Marker` de Google Maps — Google Maps solo acepta imágenes como
/// ícono de marcador, no widgets en vivo, así que se dibuja una vez
/// sobre un `Canvas` y se exporta a PNG.
Future<BitmapDescriptor> heartPinBitmap({
  required Color color,
  double size = 96,
  Color heartColor = Colors.white,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final pixelSize = size * 2; // resolución extra para que se vea nítido

  void paintIcon(
    IconData icon,
    double iconSize,
    Color iconColor,
    Offset center,
  ) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: iconColor,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  final center = Offset(pixelSize / 2, pixelSize / 2);
  paintIcon(Icons.location_on, pixelSize, color, center);
  paintIcon(
    Icons.favorite,
    pixelSize * 0.34,
    heartColor,
    center - Offset(0, pixelSize * 0.13),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(pixelSize.round(), pixelSize.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

/// Punto simple (círculo relleno con borde blanco) para marcar "tú
/// estás aquí" en el mapa.
Future<BitmapDescriptor> dotBitmap({
  required Color color,
  double size = 44,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final pixelSize = size * 2;
  final center = Offset(pixelSize / 2, pixelSize / 2);
  final radius = pixelSize / 2 - 4;

  canvas.drawCircle(center, radius, Paint()..color = Colors.white);
  canvas.drawCircle(center, radius - 3, Paint()..color = color);

  final picture = recorder.endRecording();
  final image = await picture.toImage(pixelSize.round(), pixelSize.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}
