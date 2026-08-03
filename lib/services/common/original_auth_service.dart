import 'package:supabase_flutter/supabase_flutter.dart';

class OriginalAuthException implements Exception {
  final String message;
  OriginalAuthException(this.message);

  @override
  String toString() => message;
}

/// Verificación de correo vía Original Auth durante el registro. Ver
/// ORIGINAL_AUTH_INTEGRATION.md — Original Auth no se usa para login,
/// sesión, recuperar contraseña ni eliminar cuenta; solo para esto.
class OriginalAuthService {
  OriginalAuthService._();
  static final OriginalAuthService instance = OriginalAuthService._();
  SupabaseClient get _client => Supabase.instance.client;

  /// Dispara el envío del código de verificación al correo del usuario
  /// recién registrado en Supabase. Devuelve el token de verificación
  /// solo si el ambiente de Original Auth es `test` (ahí no se manda
  /// correo real; en `prod` esto siempre es `null` y el usuario lo
  /// obtiene de su correo).
  Future<String?> startEmailVerification({required String password}) async {
    try {
      final response = await _client.functions.invoke(
        'originalauth-register',
        body: {'password': password},
      );
      if (response.status != 200) {
        throw OriginalAuthException(
          _extractMessage(response.data) ??
              'No se pudo iniciar la verificación de correo.',
        );
      }
      final data = response.data;
      return data is Map ? data['testToken'] as String? : null;
    } on OriginalAuthException {
      rethrow;
    } on FunctionException catch (e) {
      throw OriginalAuthException(
        _extractMessage(e.details) ??
            'No se pudo iniciar la verificación de correo (${e.status}).',
      );
    }
  }

  /// Confirma el código de 6 dígitos recibido por correo.
  Future<void> verifyEmailCode(String code) async {
    try {
      final response = await _client.functions.invoke(
        'originalauth-verify-email',
        body: {'code': code},
      );
      if (response.status != 200) {
        throw OriginalAuthException(
          _extractMessage(response.data) ?? 'Código inválido o vencido.',
        );
      }
    } on OriginalAuthException {
      rethrow;
    } on FunctionException catch (e) {
      throw OriginalAuthException(
        _extractMessage(e.details) ??
            'Código inválido o vencido (${e.status}).',
      );
    }
  }

  Future<void> resendVerificationCode() async {
    try {
      final response = await _client.functions.invoke(
        'originalauth-resend-verification',
      );
      if (response.status != 200) {
        throw OriginalAuthException(
          _extractMessage(response.data) ?? 'No se pudo reenviar el código.',
        );
      }
    } on OriginalAuthException {
      rethrow;
    } on FunctionException catch (e) {
      throw OriginalAuthException(
        _extractMessage(e.details) ??
            'No se pudo reenviar el código (${e.status}).',
      );
    }
  }

  String? _extractMessage(Object? data) {
    if (data is Map) return data['error'] as String?;
    return null;
  }
}
