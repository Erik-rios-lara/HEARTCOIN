import 'package:flutter/material.dart';

import '../../services/common/notification_service.dart';
import '../../theme/app_colors.dart';
import 'comments_sheet.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: () => NotificationService.instance.markAllAsRead(),
            child: const Text(
              'Marcar todas como leídas',
              style: TextStyle(color: AppColors.primarioRojo, fontSize: 12),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NotificationService.instance.notificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            );
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Text(
                'Aún no tienes notificaciones.',
                style: TextStyle(color: AppColors.gris600),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: AppColors.gris200),
            itemBuilder: (context, index) =>
                _NotificationTile(notification: notifications[index]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  const _NotificationTile({required this.notification});

  IconData get _icon {
    switch (notification['type'] as String?) {
      case 'like_post':
      case 'like_comment':
        return Icons.favorite;
      case 'reply_comment':
        return Icons.reply;
      case 'comment_post':
      default:
        return Icons.mode_comment;
    }
  }

  String get _message => NotificationService.instance.messageFor(notification);

  String get _relativeTime {
    final createdAt = DateTime.tryParse(
      notification['created_at'] as String? ?? '',
    );
    if (createdAt == null) return '';
    final diff = DateTime.now().toUtc().difference(createdAt.toUtc());
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] as bool? ?? false;
    final actorAvatar = notification['actor_avatar_url'] as String?;
    final postId = notification['post_id'] as String?;

    return InkWell(
      onTap: () async {
        if (!isRead) {
          await NotificationService.instance.markAsRead(
            notification['id'] as String,
          );
        }
        if (postId != null && context.mounted) {
          showCommentsSheet(context, postId: postId);
        }
      },
      child: Container(
        color: isRead
            ? Colors.transparent
            : AppColors.rojoClaro1.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.gris200,
                  backgroundImage: actorAvatar != null
                      ? NetworkImage(actorAvatar)
                      : null,
                  child: actorAvatar == null
                      ? Icon(Icons.person, color: AppColors.gris600)
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primarioRojo,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _message,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primarioNegro,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime,
                    style: TextStyle(fontSize: 12, color: AppColors.gris600),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primarioRojo,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
