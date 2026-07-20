import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 1. Importamos la librería de Supabase
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home_people_screen.dart';
import 'screens/home_organization_screen.dart';
import 'screens/home_company_screen.dart';
import 'screens/certificados_screen.dart';
import 'screens/mis_acciones_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/votaciones_screen.dart';
import 'screens/iniciativas_ahorro_screen.dart';
import 'screens/iniciativas_social_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/votaciones_monitor_screen.dart';
import 'screens/community_screen.dart';
import 'screens/org_iniciativas_screen.dart';
import 'screens/company_beneficios_screen.dart';
import 'screens/wallet_screen.dart';
import 'services/text_scale_controller.dart';
import 'services/location_preference_controller.dart';

void main() async {
  // 2. Convertimos el main en una función asíncrona (async)
  // 3. Línea obligatoria en Flutter antes de ejecutar código asíncrono en el main
  WidgetsFlutterBinding.ensureInitialized();

  // 4. Inicializamos Supabase con las credenciales de tu proyecto
  await Supabase.initialize(
    url:
        'https://bamrvwzpcqwoyuwbvomw.supabase.co', // 👈 Reemplaza con tu URL del panel de Supabase
    anonKey:
        'sb_publishable_h_Xb1Hwas6LzD4wWK-nEUQ_kYI3qs2m', // 👈 Reemplaza con tu Anon Key (public)
  );

  await TextScaleController.instance.load();
  await LocationPreferenceController.instance.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeartCoin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE91E63)),
      ),
      builder: (context, child) {
        return ValueListenableBuilder<double>(
          valueListenable: TextScaleController.instance.scale,
          builder: (context, scale, _) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
        );
      },
      home:
          const OnboardingScreen(), // Se mantiene tu pantalla de Onboarding como el inicio
      routes: {
        '/home-personal': (_) => const HomePeopleScreen(),
        '/home-organizacion': (_) => const HomeOrganizationScreen(),
        '/home-empresa': (_) => const HomeCompanyScreen(),
        '/votaciones': (_) => const VotacionesScreen(),
        '/certificados': (_) => const CertificadosScreen(),
        '/iniciativas-ahorro': (_) => const IniciativasAhorroScreen(),
        '/iniciativas-social': (_) => const IniciativasSocialScreen(),
        '/create-post': (_) => const CreatePostScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/search': (_) => const ExploreScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/votaciones-monitor': (_) => const VotacionesMonitorScreen(),
        '/comunidad': (_) => const CommunityScreen(),
        '/mis-iniciativas': (_) => const OrgIniciativasScreen(),
        '/mis-beneficios': (_) => const CompanyBeneficiosScreen(),
        '/wallet': (_) => const WalletScreen(),
        '/mis-acciones': (_) => const MisAccionesScreen(),
      },
    );
  }
}
