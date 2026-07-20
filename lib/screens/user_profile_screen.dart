import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/block_service.dart';
import '../theme/app_colors.dart';
import '../widgets/follow_button.dart';
import '../widgets/posts_grid.dart';

/// Perfil público de otro usuario (rol Personal). Muestra su información,
/// estadísticas, botón de seguir y sus publicaciones.
class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _client
          .from('personal_profiles')
          .select()
          .eq('id', widget.userId)
          .maybeSingle();

      final posts = await _client
          .from('publicaciones')
          .select()
          .eq('author_id', widget.userId)
          .order('created_at', ascending: false);

      final followersResponse = await _client
          .from('follows')
          .select('follower_id')
          .eq('followed_id', widget.userId)
          .count();

      final followingResponse = await _client
          .from('follows')
          .select('followed_id')
          .eq('follower_id', widget.userId)
          .count();

      final blockedIds = await BlockService.instance.fetchBlockedIds();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _posts = posts.cast<Map<String, dynamic>>();
        _followersCount = followersResponse.count;
        _followingCount = followingResponse.count;
        _isBlocked = blockedIds.contains(widget.userId);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBlock() async {
    final fullName = _profile?['full_name'] as String? ?? 'este usuario';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _isBlocked ? 'Desbloquear a $fullName' : 'Bloquear a $fullName',
        ),
        content: Text(
          _isBlocked
              ? 'Volverás a ver sus publicaciones y podrá interactuar contigo.'
              : 'Ya no verás publicaciones de $fullName y él/ella no podrá interactuar contigo. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_isBlocked ? 'Desbloquear' : 'Bloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (_isBlocked) {
        await BlockService.instance.unblockUser(widget.userId);
      } else {
        await BlockService.instance.blockUser(widget.userId);
      }
      if (mounted) setState(() => _isBlocked = !_isBlocked);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la acción.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _client.auth.currentUser?.id;
    final isOwnProfile = currentUserId == widget.userId;
    final fullName = _profile?['full_name'] as String? ?? 'Usuario HeartCoin';
    final avatarUrl = _profile?['avatar_url'] as String?;
    final bio = _profile?['bio'] as String?;
    final city = _profile?['city'] as String?;
    final country = _profile?['country'] as String?;
    final location = [
      city,
      country,
    ].where((p) => p != null && p.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: Text(fullName),
        actions: [
          if (!isOwnProfile && _profile != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'block') _toggleBlock();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'block',
                  child: Text(_isBlocked ? 'Desbloquear' : 'Bloquear'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            )
          : _profile == null
          ? Center(
              child: Text(
                'Este perfil no está disponible.',
                style: TextStyle(color: AppColors.gris600),
              ),
            )
          : RefreshIndicator(
              color: AppColors.primarioRojo,
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.gris200,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Icon(Icons.person, size: 44, color: AppColors.gris600)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fullName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarioNegro,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      location,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.gris600),
                    ),
                  ],
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.gris700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatColumn(label: 'Posts', value: _posts.length),
                      _StatDivider(),
                      _StatColumn(label: 'Followers', value: _followersCount),
                      _StatDivider(),
                      _StatColumn(label: 'Follows', value: _followingCount),
                    ],
                  ),
                  if (!isOwnProfile) ...[
                    const SizedBox(height: 16),
                    Center(child: FollowButton(targetUserId: widget.userId)),
                  ],
                  const SizedBox(height: 20),
                  Divider(height: 1, color: AppColors.gris200),
                  const SizedBox(height: 8),
                  PostsGrid(
                    posts: _posts,
                    emptyMessage: 'Aún no ha publicado nada.',
                    shrinkWrap: true,
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final int value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.gris600)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 32, width: 1, color: AppColors.gris300);
  }
}
