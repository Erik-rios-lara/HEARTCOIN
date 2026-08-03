import 'package:supabase_flutter/supabase_flutter.dart';

/// Roles soportados por HeartCoin, alineados con las tablas:
/// personal_profiles / organization_profiles / company_profiles
enum UserRole { personal, organizacion, empresa }

extension UserRoleX on UserRole {
  /// Valor guardado en `user_metadata.role` y usado como discriminador.
  String get value {
    switch (this) {
      case UserRole.personal:
        return 'personal';
      case UserRole.organizacion:
        return 'organizacion';
      case UserRole.empresa:
        return 'empresa';
    }
  }

  /// Tabla de perfil correspondiente en Supabase.
  String get profileTable {
    switch (this) {
      case UserRole.personal:
        return 'personal_profiles';
      case UserRole.organizacion:
        return 'organization_profiles';
      case UserRole.empresa:
        return 'company_profiles';
    }
  }

  static UserRole fromValue(String? value) {
    switch (value) {
      case 'organizacion':
        return UserRole.organizacion;
      case 'empresa':
        return UserRole.empresa;
      case 'personal':
      default:
        return UserRole.personal;
    }
  }
}

/// Excepción legible para mostrar en SnackBars / diálogos.
class AuthServiceException implements Exception {
  final String message;
  AuthServiceException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// ============================================================
  /// REGISTRO
  /// ============================================================
  /// Crea el usuario en Supabase Auth (guardando el rol en
  /// user_metadata) y luego inserta la fila inicial en la tabla
  /// de perfil correspondiente, incluyendo todas las columnas
  /// NON-NULLABLE de cada tabla.

  /// personal_profiles: full_name, email, country, city, profile_type
  /// son NON-NULLABLE.
  Future<void> registerPersonal({
    required String fullName,
    required String email,
    required String password,
    required String country,
    required String city,
    required String profileType,
  }) async {
    final user = await _signUp(
      email: email,
      password: password,
      role: UserRole.personal,
    );

    await _client.from(UserRole.personal.profileTable).insert({
      'id': user.id,
      'full_name': fullName,
      'email': email,
      'country': country,
      'city': city,
      'profile_type': profileType,
    });
  }

  /// organization_profiles: representative_name, position,
  /// corporate_email, country, city, organization_name,
  /// organization_type, impact_area son NON-NULLABLE.
  Future<void> registerOrganization({
    required String organizationName,
    required String representativeName,
    required String position,
    required String corporateEmail,
    required String password,
    required String country,
    required String city,
    required String organizationType,
    required String impactArea,
  }) async {
    final user = await _signUp(
      email: corporateEmail,
      password: password,
      role: UserRole.organizacion,
    );

    await _client.from(UserRole.organizacion.profileTable).insert({
      'id': user.id,
      'organization_name': organizationName,
      'representative_name': representativeName,
      'position': position,
      'corporate_email': corporateEmail,
      'country': country,
      'city': city,
      'organization_type': organizationType,
      'impact_area': impactArea,
    });
  }

  /// company_profiles: representative_name, position,
  /// corporate_email, country, city, company_name, industry,
  /// employee_range, main_goal son NON-NULLABLE.
  Future<void> registerCompany({
    required String companyName,
    required String representativeName,
    required String position,
    required String corporateEmail,
    required String password,
    required String country,
    required String city,
    required String industry,
    required String employeeRange,
    required String mainGoal,
  }) async {
    final user = await _signUp(
      email: corporateEmail,
      password: password,
      role: UserRole.empresa,
    );

    await _client.from(UserRole.empresa.profileTable).insert({
      'id': user.id,
      'company_name': companyName,
      'representative_name': representativeName,
      'position': position,
      'corporate_email': corporateEmail,
      'country': country,
      'city': city,
      'industry': industry,
      'employee_range': employeeRange,
      'main_goal': mainGoal,
    });
  }

  Future<User> _signUp({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'role': role.value},
      );

      final user = response.user;
      if (user == null) {
        throw AuthServiceException(
          'No se pudo crear la cuenta. Intenta de nuevo.',
        );
      }
      return user;
    } on AuthException catch (e) {
      throw AuthServiceException(e.message);
    }
  }

  /// ============================================================
  /// LOGIN
  /// ============================================================
  Future<UserRole> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw AuthServiceException('Correo o contraseña incorrectos.');
      }

      return UserRoleX.fromValue(user.userMetadata?['role'] as String?);
    } on AuthException catch (e) {
      throw AuthServiceException(e.message);
    }
  }

  UserRole? get currentRole {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return UserRoleX.fromValue(user.userMetadata?['role'] as String?);
  }

  bool get isLoggedIn => _client.auth.currentUser != null;

  Future<void> signOut() => _client.auth.signOut();
}
