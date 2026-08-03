import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaUploadException implements Exception {
  final String message;
  MediaUploadException(this.message);

  @override
  String toString() => message;
}

class UploadedMedia {
  final String url;
  final int fileId;
  const UploadedMedia({required this.url, required this.fileId});
}

/// Sube archivos a MediaAAS a través de la Edge Function `upload-media`,
/// que firma el request con el secret_key del lado del servidor.
class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();

  Future<UploadedMedia> upload({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

      final response = await Supabase.instance.client.functions.invoke(
        'upload-media',
        files: [
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
            contentType: MediaType.parse(mimeType),
          ),
        ],
        body: {'file_name': fileName},
      );

      final data = response.data;
      if (response.status != 200 || data is! Map) {
        throw MediaUploadException('No se pudo subir el archivo.');
      }

      final url = data['image_url'] as String?;
      final fileId = data['file_id'] as int?;
      if (url == null || fileId == null) {
        throw MediaUploadException(
          'Respuesta inválida del servidor de archivos.',
        );
      }
      return UploadedMedia(url: url, fileId: fileId);
    } on FunctionException catch (e) {
      throw MediaUploadException('Error al subir (${e.status}): ${e.details}');
    }
  }
}
