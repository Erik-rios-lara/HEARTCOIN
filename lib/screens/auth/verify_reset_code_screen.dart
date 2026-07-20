import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reset_password_screen.dart';

/// Segundo paso: el usuario escribe el código de 6 dígitos que Supabase
/// envió por correo. Al verificarlo con éxito, Supabase entrega una
/// sesión temporal de recuperación (sin necesitar la contraseña vieja),
/// suficiente para el siguiente paso (`updateUser`).
class VerifyResetCodeScreen extends StatefulWidget {
  final String email;
  const VerifyResetCodeScreen({super.key, required this.email});

  @override
  State<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends State<VerifyResetCodeScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
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
    if (_isLoading) return;
    final code = _codeController.text.trim();
    if (code.length < 6) {
      _showError('Ingresa el código de 6 dígitos.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.recovery,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Código inválido o vencido. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Código reenviado.')));
    } catch (_) {
      if (mounted) _showError('No se pudo reenviar el código.');
    } finally {
      if (mounted) setState(() => _isResending = false);
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
        title: const Text('Verificar código'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa el código de 6 dígitos que enviamos a ${widget.email}.',
                style: const TextStyle(
                  fontSize: 14,
                  color: _textColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                onSubmitted: (_) => _verify(),
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF171717),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                  onPressed: _isLoading ? null : _verify,
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
                          'Verificar',
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
