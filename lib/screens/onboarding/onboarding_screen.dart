import 'package:flutter/material.dart';
import '../home/home_screen.dart';

// Paleta de colores HeartCoin
class _Colors {
  // Fondos
  static const background = Color(0xFFFFFFFF);
  static const card = Color(0xFFF8F8F8);

  // Textos
  static const title = Color(0xFF171717);
  static const text = Color(0xFF58585A);
  static const secondaryText = Color(0xFF9E9E9E);

  // Principal
  static const primary = Color(0xFFEC324C);
  static const primaryDark = Color(0xFFC51F38);

  static const buttonText = Color(0xFFFFFFFF);

  // Indicadores
  static const indicatorActive = primary;
  static const indicatorInactive = Color(0xFFD5D5D5);

  // Divider
  static const divider = Color(0xFFE9E9E9);

  // Secundarios
  static const green = Color(0xFF42B883);
  static const yellow = Color(0xFFFFCB57);
  static const orange = Color(0xFFFF8C42);
  static const purple = Color(0xFF8E44AD);

  // Versiones claras
  static const lightRed = Color(0xFFFCE8EB);
  static const lightGreen = Color(0xFFE8F7F1);
  static const lightOrange = Color(0xFFFFF1E7);
  static const lightPurple = Color(0xFFF4E9FA);
  static const lightYellow = Color(0xFFFFF8E1);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.favorite_rounded,
      iconColor: _Colors.primary,
      iconBg: _Colors.lightRed,
      title: 'Bienvenid@ a HeartCoin',
      subtitle:
          'Una forma sencilla de gestionar y seguir el impacto de tus HeartCoins.',
    ),

    _OnboardingPage(
      icon: Icons.volunteer_activism_rounded,
      iconColor: _Colors.green,
      iconBg: Color(0xFFE8F7F1),
      title: 'Acumula y comparte',
      subtitle:
          'Obtén HeartCoins participando en actividades y comparte experiencias con la comunidad.',
    ),

    _OnboardingPage(
      icon: Icons.workspace_premium_rounded,
      iconColor: _Colors.orange,
      iconBg: Color(0xFFFFF1E7),
      title: 'Canjea tus recompensas',
      subtitle:
          'Utiliza tus HeartCoins para acceder a beneficios y recompensas exclusivas.',
    ),
  ];

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _PageContent(page: _pages[index]);
                },
              ),
            ),
            _PageIndicator(count: _pages.length, current: _currentPage),
            const SizedBox(height: 32),
            _BottomButton(
              isLast: _currentPage == _pages.length - 1,
              onNext: _nextPage,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.subtitle,
  });
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;

  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: page.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 72, color: page.iconColor),
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: _Colors.title,
              height: 1.2,
            ),
          ),
          if (page.subtitle != null) ...[
            const SizedBox(height: 20),
            Text(
              page.subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                color: _Colors.text,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _PageIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? _Colors.indicatorActive
                : _Colors.indicatorInactive,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final bool isLast;
  final VoidCallback onNext;

  const _BottomButton({required this.isLast, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: _Colors.primary,
            foregroundColor: _Colors.buttonText,
            disabledBackgroundColor: _Colors.primary.withValues(alpha: 0.35),
            disabledForegroundColor: _Colors.buttonText.withValues(alpha: 0.7),

            elevation: 4,
            shadowColor: _Colors.primary.withValues(alpha: 0.30),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),

            padding: const EdgeInsets.symmetric(vertical: 16),

            animationDuration: const Duration(milliseconds: 200),
          ),
          child: Text(
            isLast ? 'Empezar' : 'Siguiente',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: _Colors.buttonText,
            ),
          ),
        ),
      ),
    );
  }
}
