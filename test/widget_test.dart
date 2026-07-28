import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heartcoin/screens/onboarding/onboarding_screen.dart';
import 'package:heartcoin/screens/home/home_screen.dart';
import 'package:heartcoin/screens/auth/login_screen.dart';
import 'package:heartcoin/screens/auth/register_screen.dart';
import 'package:heartcoin/widgets/iniciativa_widgets.dart';

/// Envuelve un widget de pantalla en un MaterialApp mínimo, igual que lo
/// vería en producción pero sin depender de Supabase.initialize() (que
/// solo se ejecuta en main() y no hace falta para estas pantallas).
Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('OnboardingScreen', () {
    testWidgets('muestra la primera página con su título y el botón '
        '"Siguiente"', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));

      expect(find.text('Bienvenid@ a HeartCoin'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);
      expect(find.text('Empezar'), findsNothing);
    });

    testWidgets('el botón cambia a "Empezar" y navega a HomeScreen al '
        'llegar a la última página', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));

      // Avanza las 3 páginas del onboarding.
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Canjea tus recompensas'), findsOneWidget);
      expect(find.text('Empezar'), findsOneWidget);

      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });

  group('HomeScreen', () {
    testWidgets('el botón "Registrarse" navega a RegisterScreen', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const HomeScreen()));

      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('el botón "Iniciar sesión" navega a LoginScreen', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const HomeScreen()));

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    testWidgets('muestra un error y no intenta iniciar sesión si el '
        'correo y la contraseña están vacíos', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      // "Iniciar sesión" aparece dos veces (título de la pantalla y
      // botón); se apunta específicamente al botón. El botón puede
      // quedar fuera del viewport de prueba (800x600), así que se
      // asegura visibilidad antes de tocarlo.
      final loginButton = find.widgetWithText(ElevatedButton, 'Iniciar sesión');
      await tester.ensureVisible(loginButton);
      await tester.pumpAndSettle();
      await tester.tap(loginButton);
      // La validación de campos vacíos es síncrona y nunca llega a
      // llamar a Supabase; se avanza un frame para que el SnackBar
      // termine su animación de entrada.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ingresa tu correo y contraseña.'), findsOneWidget);
    });

    testWidgets('el enlace "¿Olvidaste tu contraseña?" está presente', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    });
  });

  group('AppChip', () {
    testWidgets('refleja el estado seleccionado en su color de fondo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: AppChip(label: 'Voluntariado', selected: true, onTap: () {}),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNot(Colors.white));
    });

    testWidgets('dispara onTap al presionarlo', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: AppChip(
              label: 'Crowdfunding',
              selected: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Crowdfunding'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
