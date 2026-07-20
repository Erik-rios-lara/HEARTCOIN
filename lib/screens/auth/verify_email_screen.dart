import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/original_auth_service.dart';
import 'login_screen.dart';

/// Bloquea el paso a la app hasta que el usuario confirme el código de
/// verificación que Original Auth envió a su correo al registrarse.
/// Ver ORIGINAL_AUTH_INTEGRATION.md.
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final UserRole role;

  /// Solo viene en el ambiente `test` de Original Auth (ahí no se manda
  /// correo real). En `prod` siempre es null y el usuario escribe el
  /// código que recibió por correo.
  final String? testToken;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.role,
    this.testToken,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final _codeController = TextEditingController(
    text: widget.testToken ?? '',
  );
  bool _isVerifying = false;
  bool _isResending = false;

  static const _primary = Color(0xFFEC324C);
  static const _textColor = Color(0xFF58585A);
  static const _borderColor = Color(0xFFE9E9E9);

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_isVerifying) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError('Ingresa el código de verificación.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await OriginalAuthService.instance.verifyEmailCode(code);
      if (!mounted) return;
      _navigateToHome();
    } on OriginalAuthException catch (e) {
      _showError(e.toString());
    } catch (_) {
      _showError('No se pudo verificar el código. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      await OriginalAuthService.instance.resendVerificationCode();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Código reenviado.')));
    } on OriginalAuthException catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _signOutAndExit() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _navigateToHome() {
    final routeName = switch (widget.role) {
      UserRole.personal => '/home-personal',
      UserRole.organizacion => '/home-organizacion',
      UserRole.empresa => '/home-empresa',
    };
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (_) => false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: _primary));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF171717),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Verifica tu correo'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa el código de verificación que enviamos a ${widget.email} para confirmar tu cuenta.',
                style: const TextStyle(
                  fontSize: 14,
                  color: _textColor,
                  height: 1.4,
                ),
              ),
              if (widget.testToken != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Ambiente de prueba: el código se autocompletó porque este correo no se envía de verdad en test.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8A5A00)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                onSubmitted: (_) => _verify(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF171717),
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _borderColor,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isResending ? null : _resend,
                  child: Text(
                    _isResending ? 'Reenviando...' : 'Reenviar código',
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: _primary.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verificar',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _signOutAndExit,
                  child: Text(
                    'Cerrar sesión y salir',
                    style: TextStyle(color: _textColor, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
