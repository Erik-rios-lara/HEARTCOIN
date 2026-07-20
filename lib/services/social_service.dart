import 'package:supabase_flutter/supabase_flutter.dart';

/// Likes de publicaciones y comentarios, y creación de comentarios
/// (con un nivel de respuestas vía parent_comment_id).
class SocialService {
  SocialService._();
  static final SocialService instance = SocialService._();

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No hay sesión activa.');
    return id;
  }

  Future<bool> hasLikedPost(String postId) async {
    final row = await _client
        .from('post_likes')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', _userId)
        .maybeSingle();
    return row != null;
  }

  /// Da o quita el like del usuario actual sobre una publicación.
  /// Devuelve el nuevo estado (true = ahora tiene like).
  Future<bool> toggleLikePost(String postId) async {
    final alreadyLiked = await hasLikedPost(postId);
    if (alreadyLiked) {
      await _client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', _userId);
      return false;
    } else {
      await _client.from('post_likes').insert({
        'post_id': postId,
        'user_id': _userId,
      });
      return true;
    }
  }

  Future<bool> hasLikedComment(String commentId) async {
    final row = await _client
        .from('comment_likes')
        .select('comment_id')
        .eq('comment_id', commentId)
        .eq('user_id', _userId)
        .maybeSingle();
    return row != null;
  }

  Future<bool> toggleLikeComment(String commentId) async {
    final alreadyLiked = await hasLikedComment(commentId);
    if (alreadyLiked) {
      await _client
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', _userId);
      return false;
    } else {
      await _client.from('comment_likes').insert({
        'comment_id': commentId,
        'user_id': _userId,
      });
      return true;
    }
  }

  Stream<List<Map<String, dynamic>>> commentsStream(String postId) {
    return _client
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at');
  }

  Future<void> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    final profile = await _client
        .from('personal_profiles')
        .select()
        .eq('id', _userId)
        .maybeSingle();

    await _client.from('comments').insert({
      'post_id': postId,
      'parent_comment_id': parentCommentId,
      'author_id': _userId,
      'author_name': profile?['full_name'] as String? ?? 'Usuario HeartCoin',
      'author_avatar_url': profile?['avatar_url'] as String?,
      'content': content,
    });
  }

  /// Borra un comentario propio. Si tiene respuestas, se borran en
  /// cascada (FK `parent_comment_id` con `ON DELETE CASCADE`).
  Future<void> deleteComment(String commentId) async {
    await _client.from('comments').delete().eq('id', commentId);
  }
}
