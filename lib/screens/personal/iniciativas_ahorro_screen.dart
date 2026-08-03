import 'package:flutter/material.dart';

import 'create_iniciativa_ahorro_screen.dart';
import 'iniciativas_by_category_screen.dart';

class IniciativasAhorroScreen extends StatelessWidget {
  const IniciativasAhorroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return IniciativasByCategoryScreen(
      category: 'Ahorro',
      title: 'Iniciativas de ahorro',
      searchHint: 'Buscar iniciativas de ahorro...',
      emptyMessage: 'Aún no hay iniciativas de ahorro.',
      onCreate: (context) => Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CreateIniciativaAhorroScreen()),
      ),
    );
  }
}
