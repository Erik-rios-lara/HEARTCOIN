import 'package:flutter/material.dart';

import '../screens/iniciativa_detail_screen.dart';
import '../theme/app_colors.dart';
import 'save_button.dart';

enum IniciativaSortOption { cercanos, popular, reciente }

/// Chip de selección simple (usado por categorías y orden en Explorar
/// e Iniciativas de ahorro).
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarioRojo : AppColors.primarioBlanco,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primarioRojo : AppColors.gris300,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.gris700,
          ),
        ),
      ),
    );
  }
}

class IniciativaSortChips extends StatelessWidget {
  final IniciativaSortOption selected;
  final ValueChanged<IniciativaSortOption> onSelected;
  final bool scrollable;

  const IniciativaSortChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.scrollable = false,
  });

  static const _labels = {
    IniciativaSortOption.cercanos: 'Cercanos',
    IniciativaSortOption.popular: 'Popular',
    IniciativaSortOption.reciente: 'Reciente',
  };

  @override
  Widget build(BuildContext context) {
    final chips = IniciativaSortOption.values
        .map(
          (option) => AppChip(
            label: _labels[option]!,
            selected: selected == option,
            onTap: () => onSelected(option),
          ),
        )
        .toList();

    if (!scrollable) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: chips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) => chips[index],
    );
  }
}

/// Tarjeta de una iniciativa (usada en Explorar e Iniciativas de ahorro).
class IniciativaCard extends StatelessWidget {
  final Map<String, dynamic> iniciativa;
  const IniciativaCard({super.key, required this.iniciativa});

  @override
  Widget build(BuildContext context) {
    final title = iniciativa['title'] as String? ?? 'Iniciativa';
    final description = iniciativa['description'] as String?;
    final category = iniciativa['category'] as String? ?? '';
    final location = iniciativa['location'] as String?;
    final imageUrl = iniciativa['image_url'] as String?;
    final organizationName = iniciativa['organization_name'] as String?;
    final votesCount = (iniciativa['votes_count'] as num?)?.toInt() ?? 0;
    final iniciativaId = iniciativa['id'] as String?;

    return Material(
      color: AppColors.primarioBlanco,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IniciativaDetailScreen(iniciativa: iniciativa),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.gris200,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.gris600,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.rojoClaro1.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarioRojo,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.thumb_up_alt_outlined,
                        size: 14,
                        color: AppColors.gris600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$votesCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.gris600,
                        ),
                      ),
                      if (iniciativaId != null) ...[
                        const SizedBox(width: 8),
                        SaveButton(
                          itemType: 'iniciativa',
                          itemId: iniciativaId,
                          color: AppColors.primarioRojo,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarioNegro,
                    ),
                  ),
                  if (organizationName != null &&
                      organizationName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.apartment,
                          size: 13,
                          color: AppColors.gris600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            organizationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gris700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppColors.gris700),
                    ),
                  ],
                  if (location != null && location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.gris600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.gris600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
