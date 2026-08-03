import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../services/common/auth_service.dart';
import '../../services/common/original_auth_service.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  UserRole _selectedRole = UserRole.personal;
  bool _passwordVisible = false;
  bool _isLoading = false;

  // Comunes
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();

  // Personal -> personal_profiles
  final _fullNameController = TextEditingController();
  String _profileType = 'Voluntario';

  // Organización -> organization_profiles
  final _organizationNameController = TextEditingController();
  final _representativeNameOrgController = TextEditingController();
  final _positionOrgController = TextEditingController();
  String _organizationType = 'Fundación';
  String _impactArea = 'Educación';

  // Empresa -> company_profiles
  final _companyNameController = TextEditingController();
  final _representativeNameCompanyController = TextEditingController();
  final _positionCompanyController = TextEditingController();
  String _industry = 'Tecnología';
  String _employeeRange = '1-10';
  String _mainGoal = 'Responsabilidad Social Empresarial (RSE)';

  static const _primary = Color(0xFFEC324C);
  static const _cardColor = Color(0xFF171717);
  static const _textColor = Color(0xFFB0B0B0);
  static const _hintColor = Color(0xFF8A8A8A);

  // Debe coincidir exactamente con el check constraint de
  // personal_profiles.profile_type en Supabase.
  static const _profileTypeOptions = [
    'Voluntario',
    'Emprendedor',
    'Profesional',
    'Estudiante',
    'Investigador',
    'Otro',
  ];
  // Debe coincidir exactamente con el check constraint de
  // organization_profiles.organization_type en Supabase.
  static const _organizationTypeOptions = [
    'Fundación',
    'Asociación Civil',
    'ONG',
    'Cooperativa',
    'Gobierno',
    'Universidad',
    'Comunidad',
    'Organización Internacional',
    'Otra',
  ];
  static const _impactAreaOptions = [
    'Educación',
    'Salud',
    'Medio ambiente',
    'Derechos humanos',
    'Pobreza',
    'Otro',
  ];
  static const _industryOptions = [
    'Tecnología',
    'Manufactura',
    'Servicios',
    'Retail',
    'Finanzas',
    'Salud',
    'Educación',
    'Otro',
  ];
  // Debe coincidir exactamente con el check constraint de
  // company_profiles.employee_range en Supabase.
  static const _employeeRangeOptions = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '501-1000',
    'Más de 1000',
  ];
  // Debe coincidir exactamente con el check constraint de
  // company_profiles.main_goal en Supabase.
  static const _mainGoalOptions = [
    'Medición de impacto',
    'ESG',
    'Responsabilidad Social Empresarial (RSE)',
    'Voluntariado corporativo',
    'Donaciones',
    'Marketplace de impacto',
    'Comunidad',
    'Reclutamiento de talento social',
    'Otro',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _fullNameController.dispose();
    _organizationNameController.dispose();
    _representativeNameOrgController.dispose();
    _positionOrgController.dispose();
    _companyNameController.dispose();
    _representativeNameCompanyController.dispose();
    _positionCompanyController.dispose();
    super.dispose();
  }

  Future<void> _onCreateAccount() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final country = _countryController.text.trim();
    final city = _cityController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Completa el correo y la contraseña.');
      return;
    }
    if (password.length < 6) {
      _showError('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (country.isEmpty || city.isEmpty) {
      _showError('Completa el país y la ciudad.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      switch (_selectedRole) {
        case UserRole.personal:
          if (_fullNameController.text.trim().isEmpty) {
            _showError('Ingresa tu nombre completo.');
            return;
          }
          await AuthService.instance.registerPersonal(
            fullName: _fullNameController.text.trim(),
            email: email,
            password: password,
            country: country,
            city: city,
            profileType: _profileType,
          );
          break;

        case UserRole.organizacion:
          if (_organizationNameController.text.trim().isEmpty ||
              _representativeNameOrgController.text.trim().isEmpty ||
              _positionOrgController.text.trim().isEmpty) {
            _showError(
              'Completa el nombre de la organización, representante y cargo.',
            );
            return;
          }
          await AuthService.instance.registerOrganization(
            organizationName: _organizationNameController.text.trim(),
            representativeName: _representativeNameOrgController.text.trim(),
            position: _positionOrgController.text.trim(),
            corporateEmail: email,
            password: password,
            country: country,
            city: city,
            organizationType: _organizationType,
            impactArea: _impactArea,
          );
          break;

        case UserRole.empresa:
          if (_companyNameController.text.trim().isEmpty ||
              _representativeNameCompanyController.text.trim().isEmpty ||
              _positionCompanyController.text.trim().isEmpty) {
            _showError(
              'Completa el nombre de la empresa, representante y cargo.',
            );
            return;
          }
          await AuthService.instance.registerCompany(
            companyName: _companyNameController.text.trim(),
            representativeName: _representativeNameCompanyController.text
                .trim(),
            position: _positionCompanyController.text.trim(),
            corporateEmail: email,
            password: password,
            country: country,
            city: city,
            industry: _industry,
            employeeRange: _employeeRange,
            mainGoal: _mainGoal,
          );
          break;
      }

      if (!mounted) return;
      String? testToken;
      try {
        testToken = await OriginalAuthService.instance.startEmailVerification(
          password: password,
        );
      } on OriginalAuthException catch (e) {
        if (!mounted) return;
        _showError(e.toString());
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: email,
            role: _selectedRole,
            testToken: testToken,
          ),
        ),
        (_) => false,
      );
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _cardColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen de fondo (parte superior)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height * 0.40,
            child: Image.asset('assets/register.png', fit: BoxFit.cover),
          ),

          // Overlay degradado
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height * 0.40,
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
                    onTap: () => Navigator.of(context).maybePop(),
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

                const Spacer(),

                // Título sobre la imagen, pegado al borde de la tarjeta
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Crear cuenta',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Únete a la comunidad y empieza a generar impacto.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tarjeta inferior: llega exactamente a la mitad de la
                // pantalla (igual que en login), sin importar la altura
                // de la imagen de fondo. El formulario es largo, así que
                // se desplaza dentro de ese espacio fijo con
                // SingleChildScrollView (también cubre cuando se abre el
                // teclado).
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RoleTabSelector(
                            selectedRole: _selectedRole,
                            onChanged: (role) {
                              if (_isLoading) return;
                              setState(() => _selectedRole = role);
                            },
                          ),
                          const SizedBox(height: 20),

                          // ============== CAMPOS ESPECÍFICOS DEL ROL ==============
                          if (_selectedRole == UserRole.personal) ...[
                            _InputField(
                              controller: _fullNameController,
                              label: 'Nombre completo',
                              hint: 'John Doe',
                            ),
                            const SizedBox(height: 16),
                            _DropdownField(
                              label: 'Tipo de perfil',
                              value: _profileType,
                              options: _profileTypeOptions,
                              onChanged: (v) =>
                                  setState(() => _profileType = v),
                            ),
                            const SizedBox(height: 16),
                          ] else if (_selectedRole ==
                              UserRole.organizacion) ...[
                            _InputField(
                              controller: _organizationNameController,
                              label: 'Nombre de la organización',
                              hint: 'Fundación Honoris Causa',
                            ),
                            const SizedBox(height: 16),
                            _InputField(
                              controller: _representativeNameOrgController,
                              label: 'Nombre del representante',
                              hint: 'Jane Doe',
                            ),
                            const SizedBox(height: 16),
                            _InputField(
                              controller: _positionOrgController,
                              label: 'Cargo del representante',
                              hint: 'Directora de proyectos',
                            ),
                            const SizedBox(height: 16),
                            _DropdownField(
                              label: 'Tipo de organización',
                              value: _organizationType,
                              options: _organizationTypeOptions,
                              onChanged: (v) =>
                                  setState(() => _organizationType = v),
                            ),
                            const SizedBox(height: 16),
                            _DropdownField(
                              label: 'Área de impacto',
                              value: _impactArea,
                              options: _impactAreaOptions,
                              onChanged: (v) => setState(() => _impactArea = v),
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            _InputField(
                              controller: _companyNameController,
                              label: 'Nombre de la empresa',
                              hint: 'Acme Inc.',
                            ),
                            const SizedBox(height: 16),
                            _InputField(
                              controller: _representativeNameCompanyController,
                              label: 'Nombre del representante',
                              hint: 'Jane Doe',
                            ),
                            const SizedBox(height: 16),
                            _InputField(
                              controller: _positionCompanyController,
                              label: 'Cargo del representante',
                              hint: 'Director de RSE',
                            ),
                            const SizedBox(height: 16),
                            _DropdownField(
                              label: 'Industria',
                              value: _industry,
                              options: _industryOptions,
                              onChanged: (v) => setState(() => _industry = v),
                            ),
                            const SizedBox(height: 16),
                            _DropdownField(
                              label: 'Número de empleados',
                              value: _employeeRange,
                              options: _employeeRangeOptions,
                              onChanged: (v) =>
                                  setState(() => _employeeRange = v),
                            ),
                            const SizedBox(height: 16),
                            _DropdownField(
                              label: 'Objetivo principal',
                              value: _mainGoal,
                              options: _mainGoalOptions,
                              onChanged: (v) => setState(() => _mainGoal = v),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ============== CAMPOS COMUNES ==============
                          Row(
                            children: [
                              Expanded(
                                child: _InputField(
                                  controller: _countryController,
                                  label: 'País',
                                  hint: 'México',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InputField(
                                  controller: _cityController,
                                  label: 'Ciudad',
                                  hint: 'Durango',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _InputField(
                            controller: _emailController,
                            label: _selectedRole == UserRole.personal
                                ? 'Correo electrónico'
                                : 'Correo corporativo',
                            hint: 'juan@ejemplo.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),

                          _InputField(
                            controller: _passwordController,
                            label: 'Contraseña',
                            hint: '••••••••••••',
                            obscureText: !_passwordVisible,
                            textInputAction: TextInputAction.done,
                            suffix: IconButton(
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _hintColor,
                                size: 20,
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _onCreateAccount,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: _primary.withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
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
                                      'Crear cuenta',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: _textColor,
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(text: '¿Ya tienes cuenta? '),
                                TextSpan(
                                  text: 'Iniciar sesión',
                                  style: const TextStyle(
                                    color: _primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = _isLoading
                                        ? null
                                        : () => Navigator.of(context)
                                              .pushReplacement(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const LoginScreen(),
                                                ),
                                              ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom,
                          ),
                        ],
                      ),
                    ),
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

/// Selector tipo "pill" con 3 opciones (Personal / Organización / Empresa).
class _RoleTabSelector extends StatelessWidget {
  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;

  const _RoleTabSelector({required this.selectedRole, required this.onChanged});

  static const _labels = {
    UserRole.personal: 'Personal',
    UserRole.organizacion: 'Organización',
    UserRole.empresa: 'Empresa',
  };

  static const _primary = Color(0xFFEC324C);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / UserRole.values.length;
        final selectedIndex = UserRole.values.indexOf(selectedRole);

        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment(
                  -1 + (2 / (UserRole.values.length - 1)) * selectedIndex,
                  0,
                ),
                child: Container(
                  width: tabWidth - 8,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              Row(
                children: UserRole.values.map((role) {
                  final isSelected = role == selectedRole;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(role),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          _labels[role]!,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF9E9E9E),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Campo de texto con el mismo estilo usado en LoginScreen.
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? suffix;
  final int maxLines;

  static const _fillColor = Color(0xFF262626);
  static const _labelColor = Color(0xFFB0B0B0);
  static const _hintColor = Color(0xFF7A7A7A);

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.suffix,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _labelColor)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: obscureText ? 1 : maxLines,
          style: const TextStyle(fontSize: 15, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 15, color: _hintColor),
            suffixIcon: suffix,
            filled: true,
            fillColor: _fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFEC324C),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Selector desplegable con el mismo estilo visual que _InputField,
/// usado para columnas NON-NULLABLE que mapean mejor a un catálogo
/// cerrado de opciones (industry, organization_type, impact_area, etc).
class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  static const _fillColor = Color(0xFF262626);
  static const _labelColor = Color(0xFFB0B0B0);

  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _labelColor)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: _fillColor,
          style: const TextStyle(fontSize: 15, color: Colors.white),
          icon: const Icon(Icons.keyboard_arrow_down, color: _labelColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: _fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFEC324C),
                width: 1.5,
              ),
            ),
          ),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
