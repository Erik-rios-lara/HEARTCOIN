import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

/// Preferencias de qué tipo de notificaciones recibe el usuario.
/// Los switches se guardan en `personal_profiles` y son respetados
/// directamente por los triggers que generan cada notificación.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _notifyLikes = true;
  bool _notifyComments = true;
  bool _notifyReplies = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _client
          .from('personal_profiles')
          .select('notify_likes, notify_comments, notify_replies')
          .eq('id', userId)
          .maybeSingle();
      if (mounted && data != null) {
        setState(() {
          _notifyLikes = data['notify_likes'] as bool? ?? true;
          _notifyComments = data['notify_comments'] as bool? ?? true;
          _notifyReplies = data['notify_replies'] as bool? ?? true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _update(String column, bool value) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('personal_profiles')
          .update({column: value})
          .eq('id', userId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el cambio.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Notificaciones'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _PreferenceTile(
                  icon: Icons.favorite_border,
                  title: 'Me gusta',
                  subtitle:
                      'Cuando alguien le da like a tus publicaciones o comentarios.',
                  value: _notifyLikes,
                  onChanged: (v) {
                    setState(() => _notifyLikes = v);
                    _update('notify_likes', v);
                  },
                ),
                const SizedBox(height: 12),
                _PreferenceTile(
                  icon: Icons.mode_comment_outlined,
                  title: 'Comentarios',
                  subtitle: 'Cuando alguien comenta una de tus publicaciones.',
                  value: _notifyComments,
                  onChanged: (v) {
                    setState(() => _notifyComments = v);
                    _update('notify_comments', v);
                  },
                ),
                const SizedBox(height: 12),
                _PreferenceTile(
                  icon: Icons.reply_outlined,
                  title: 'Respuestas',
                  subtitle: 'Cuando alguien responde a uno de tus comentarios.',
                  value: _notifyReplies,
                  onChanged: (v) {
                    setState(() => _notifyReplies = v);
                    _update('notify_replies', v);
                  },
                ),
              ],
            ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarioBlanco,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primarioRojo, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primarioNegro,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppColors.gris600),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primarioRojo,
          ),
        ],
      ),
    );
  }
}
