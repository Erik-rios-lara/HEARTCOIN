import 'package:flutter/material.dart';

import 'iniciativas_by_category_screen.dart';

class IniciativasSocialScreen extends StatelessWidget {
  const IniciativasSocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const IniciativasByCategoryScreen(
      category: 'Social',
      title: 'Iniciativas social',
      searchHint: 'Buscar iniciativas sociales...',
      emptyMessage: 'Aún no hay iniciativas sociales.',
    );
  }
}
