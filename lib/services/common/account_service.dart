import 'package:supabase_flutter/supabase_flutter.dart';

class DeleteAccountException implements Exception {
  final String message;
  DeleteAccountException(this.message);

  @override
  String toString() => message;
}

class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();
  SupabaseClient get _client => Supabase.instance.client;

  /// Elimina permanentemente la cuenta del usuario autenticado (vía Edge
  /// Function, que usa la Service Role Key del lado del servidor). Todas
  /// las tablas relacionadas (perfil, publicaciones, votos, check-ins,
  /// HC, etc.) se eliminan en cascada.
  Future<void> deleteAccount() async {
    try {
      final response = await _client.functions.invoke('delete-account');
      if (response.status != 200) {
        throw DeleteAccountException(
          'No se pudo eliminar la cuenta. Intenta de nuevo.',
        );
      }
    } on DeleteAccountException {
      rethrow;
    } catch (_) {
      throw DeleteAccountException(
        'No se pudo eliminar la cuenta. Intenta de nuevo.',
      );
    }
  }
}
