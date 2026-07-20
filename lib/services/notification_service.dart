import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  Stream<List<Map<String, dynamic>>> notificationsStream() {
    final userId = _userId;
    if (userId == null) return const Stream.empty();
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Texto legible para una fila de la tabla `notifications`.
  String messageFor(Map<String, dynamic> notification) {
    final actorName = notification['actor_name'] as String? ?? 'Alguien';
    switch (notification['type'] as String?) {
      case 'like_post':
        return '$actorName le dio like a tu publicación';
      case 'comment_post':
        return '$actorName comentó tu publicación';
      case 'reply_comment':
        return '$actorName respondió tu comentario';
      case 'like_comment':
        return '$actorName le dio like a tu comentario';
      default:
        return '$actorName interactuó contigo';
    }
  }
}
