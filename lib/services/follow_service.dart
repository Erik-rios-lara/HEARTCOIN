import 'package:supabase_flutter/supabase_flutter.dart';

class FollowService {
  FollowService._();
  static final FollowService instance = FollowService._();
  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No hay sesión activa.');
    return id;
  }

  Future<bool> isFollowing(String targetUserId) async {
    final row = await _client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', _userId)
        .eq('followed_id', targetUserId)
        .maybeSingle();
    return row != null;
  }

  /// Sigue o deja de seguir a [targetUserId]. Devuelve el nuevo estado
  /// (true = ahora lo sigue).
  Future<bool> toggleFollow(String targetUserId) async {
    final following = await isFollowing(targetUserId);
    if (following) {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', _userId)
          .eq('followed_id', targetUserId);
      return false;
    } else {
      await _client.from('follows').insert({
        'follower_id': _userId,
        'followed_id': targetUserId,
      });
      return true;
    }
  }
}
