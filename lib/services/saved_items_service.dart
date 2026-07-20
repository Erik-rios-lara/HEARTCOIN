import 'package:supabase_flutter/supabase_flutter.dart';

class SavedItemsService {
  SavedItemsService._();
  static final SavedItemsService instance = SavedItemsService._();
  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<bool> isSaved(String itemType, String itemId) async {
    final userId = _userId;
    if (userId == null) return false;
    final row = await _client
        .from('saved_items')
        .select('id')
        .eq('user_id', userId)
        .eq('item_type', itemType)
        .eq('item_id', itemId)
        .maybeSingle();
    return row != null;
  }

  /// Guarda o quita un elemento guardado. Devuelve el nuevo estado
  /// (true = ahora está guardado).
  Future<bool> toggleSave(String itemType, String itemId) async {
    final userId = _userId;
    if (userId == null) throw StateError('No hay sesión activa.');

    final saved = await isSaved(itemType, itemId);
    if (saved) {
      await _client
          .from('saved_items')
          .delete()
          .eq('user_id', userId)
          .eq('item_type', itemType)
          .eq('item_id', itemId);
      return false;
    } else {
      await _client.from('saved_items').insert({
        'user_id': userId,
        'item_type': itemType,
        'item_id': itemId,
      });
      return true;
    }
  }

  Stream<List<Map<String, dynamic>>> savedItemsStream() {
    final userId = _userId;
    final query = _client.from('saved_items').stream(primaryKey: ['id']);
    if (userId == null) return query;
    return query.eq('user_id', userId);
  }

  /// Trae los detalles reales (título, categoría, etc.) de cada
  /// elemento guardado, combinando iniciativas y votaciones.
  Future<List<Map<String, dynamic>>> fetchSavedItemsWithDetails() async {
    final userId = _userId;
    if (userId == null) return [];

    final saved = await _client
        .from('saved_items')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final iniciativaIds = saved
        .where((s) => s['item_type'] == 'iniciativa')
        .map((s) => s['item_id'] as String)
        .toList();
    final votacionIds = saved
        .where((s) => s['item_type'] == 'votacion')
        .map((s) => s['item_id'] as String)
        .toList();

    final iniciativas = iniciativaIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('iniciativas')
              .select('id, title, category, organization_name')
              .inFilter('id', iniciativaIds);
    final votaciones = votacionIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('votaciones')
              .select('id, title, type, foundation_name, hc_reward')
              .inFilter('id', votacionIds);

    final iniciativasById = {for (final i in iniciativas) i['id']: i};
    final votacionesById = {for (final v in votaciones) v['id']: v};

    return saved
        .map((s) {
          final itemType = s['item_type'] as String;
          final itemId = s['item_id'] as String;
          final detail = itemType == 'iniciativa'
              ? iniciativasById[itemId]
              : votacionesById[itemId];
          if (detail == null) return null;
          return {
            'item_type': itemType,
            'item_id': itemId,
            'saved_at': s['created_at'],
            'detail': detail,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }
}
