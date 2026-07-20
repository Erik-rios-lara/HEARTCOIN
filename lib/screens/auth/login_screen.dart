import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _passwordVisible = false;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static const _primary = Color(0xFFEC324C);
  static const _textColor = Color(0xFF58585A);
  static const _hintColor = Color(0xFF9E9E9E);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Ingresa tu correo y contraseña.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final role = await AuthService.instance.signIn(
        email: email,
        password: password,
      );

      if (!mounted) return;
      _navigateToHome(role);
    } on AuthServiceException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: _primary));
  }

  /// Navega a la pantalla principal correspondiente al rol.
  ///
  /// NOTA: registra estas rutas en tu MaterialApp (main.dart), igual
  /// que en register_screen.dart:
  ///   routes: {
  ///     '/home-personal': (_) => const PersonalHomeScreen(),
  ///     '/home-organizacion': (_) => const OrganizationHomeScreen(),
  ///     '/home-empresa': (_) => const CompanyHomeScreen(),
  ///   }
  void _navigateToHome(UserRole role) {
    final routeName = switch (role) {
      UserRole.personal => '/home-personal',
      UserRole.organizacion => '/home-organizacion',
      UserRole.empresa => '/home-empresa',
    };
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen de fondo (parte superior)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height * 0.50,
            child: Image.asset('assets/login.png', fit: BoxFit.cover),
          ),

          // Overlay degradado sobre la imagen
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height * 0.50,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.50),
                  ],
                ),
              ),
            ),
          ),

          // Contenido completo
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Botón atrás
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // Título sobre la imagen
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Iniciar sesión',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bienvenid@ de vuelta, te hemos echado de menos.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Tarjeta inferior
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Campo: Correo electrónico
                      _InputField(
                        controller: _emailController,
                        label: 'Correo electrónico',
                        hint: 'juan@ejemplo.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),

                      const SizedBox(height: 16),

                      // Campo: Contraseña
                      _InputField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        hint: '••••••••••••',
                        obscureText: !_passwordVisible,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _onSignIn(),
                        suffix: IconButton(
                          onPressed: () {
                            setState(
                              () => _passwordVisible = !_passwordVisible,
                            );
                          },
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: _hintColor,
                            size: 20,
                          ),
                        ),
                      ),

                      // ¿Olvidaste tu contraseña?
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            final email = _emailController.text.trim();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  initialEmail: email.isEmpty ? null : email,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _primary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Divisor con "o continúa con"
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(
                              color: Color(0xFFE9E9E9),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'o continúa con',
                              style: TextStyle(fontSize: 13, color: _textColor),
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                              color: Color(0xFFE9E9E9),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Botones sociales
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SocialButton(
                            onTap: () {},
                            child: Image.network(
                              'https://www.google.com/favicon.ico',
                              width: 22,
                              height: 22,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.g_mobiledata,
                                size: 26,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          _SocialButton(
                            onTap: () {},
                            child: const Icon(
                              Icons.apple,
                              size: 26,
                              color: Color(0xFF171717),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Botón Iniciar sesión
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _onSignIn,
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
                                  'Iniciar sesión',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ¿No tienes cuenta?
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '¿No tienes cuenta? ',
                            style: TextStyle(fontSize: 14, color: _textColor),
                          ),
                          GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
                            child: const Text(
                              'Registrarse',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  static const _borderColor = Color(0xFFE9E9E9);
  static const _labelColor = Color(0xFF9E9E9E);
  static const _textColor = Color(0xFF171717);

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15, color: _textColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 13, color: _labelColor),
        hintStyle: const TextStyle(fontSize: 15, color: _labelColor),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEC324C), width: 1.5),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _SocialButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9E9E9), width: 1.5),
        ),
        child: Center(child: child),
      ),
    );
  }
}
