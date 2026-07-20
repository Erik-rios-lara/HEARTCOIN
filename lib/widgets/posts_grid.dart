import 'package:flutter/material.dart';

import '../screens/comments_sheet.dart';
import '../theme/app_colors.dart';

/// Cuadrícula de publicaciones (3 columnas) reutilizada por las pantallas
/// de perfil propio y de perfil de otros usuarios.
class PostsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final String emptyMessage;

  /// Usar `true` cuando el grid está anidado dentro de otro scrollable
  /// (por ejemplo un `ListView` de perfil), para que no requiera un
  /// tamaño acotado por sí mismo.
  final bool shrinkWrap;

  const PostsGrid({
    super.key,
    required this.posts,
    this.emptyMessage = 'Nada por aquí todavía.',
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(emptyMessage, style: TextStyle(color: AppColors.gris600)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final imageUrl = post['image_url'] as String?;
        final caption = post['caption'] as String?;

        return GestureDetector(
          onTap: () => showCommentsSheet(context, postId: post['id'] as String),
          child: imageUrl != null
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.gris200,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.gris600,
                    ),
                  ),
                )
              : Container(
                  color: AppColors.gris200,
                  padding: const EdgeInsets.all(6),
                  alignment: Alignment.center,
                  child: Text(
                    caption ?? '',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.gris700),
                  ),
                ),
        );
      },
    );
  }
}
