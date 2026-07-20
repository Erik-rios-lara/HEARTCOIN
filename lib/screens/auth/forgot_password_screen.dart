import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'verify_reset_code_screen.dart';

/// Primer paso de "olvidé mi contraseña": pide un correo (independiente
/// de cualquier sesión — el usuario todavía no está autenticado en este
/// punto) y le pide a Supabase que envíe un código de recuperación.
class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  bool _isLoading = false;

  static const _primary = Color(0xFFEC324C);
  static const _textColor = Color(0xFF58585A);
  static const _borderColor = Color(0xFFE9E9E9);
  static const _labelColor = Color(0xFF9E9E9E);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Ingresa un correo válido.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VerifyResetCodeScreen(email: email)),
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('No se pudo enviar el código. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: const Text('Recuperar contraseña'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa tu correo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF171717),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Te enviaremos un código de 6 dígitos para restablecer tu contraseña.',
                style: TextStyle(fontSize: 14, color: _textColor, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sendCode(),
                style: const TextStyle(fontSize: 15, color: Color(0xFF171717)),
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'juan@ejemplo.com',
                  labelStyle: const TextStyle(fontSize: 13, color: _labelColor),
                  hintStyle: const TextStyle(fontSize: 15, color: _labelColor),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: _primary.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Enviar código',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
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
