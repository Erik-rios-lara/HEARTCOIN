import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../services/block_service.dart';
import '../services/local_notification_service.dart';
import '../services/notification_service.dart';
import '../services/social_service.dart';
import '../widgets/follow_button.dart';
import 'comments_sheet.dart';
import 'notifications_screen.dart';
import 'user_profile_screen.dart';

/// Home del rol "personal". Registra esta pantalla en tu MaterialApp:
///   routes: {
///     '/home-personal': (_) => const HomePeopleScreen(),
///   }
class HomePeopleScreen extends StatefulWidget {
  const HomePeopleScreen({super.key});

  @override
  State<HomePeopleScreen> createState() => _HomePeopleScreenState();
}

class _HomePeopleScreenState extends State<HomePeopleScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  int _selectedTab = 0;

  Stream<List<Map<String, dynamic>>>? _feedStream;
  Map<String, dynamic>? _myProfile;
  Set<String> _blockedIds = {};

  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSub;
  Set<String> _seenNotificationIds = {};
  bool _notificationsBaselineSet = false;

  @override
  void initState() {
    super.initState();
    _feedStream = _supabase
        .from('publicaciones')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
    _loadMyProfile();
    _loadBlockedIds();
    _initLocalNotifications();
  }

  Future<void> _initLocalNotifications() async {
    await LocalNotificationService.instance.init();
    _notificationsSub = NotificationService.instance
        .notificationsStream()
        .listen(_handleNotificationsUpdate);
  }

  /// Muestra un banner del sistema solo para filas que no existían en la
  /// última actualización (evita re-notificar avisos ya vistos y no
  /// dispara nada retroactivo con lo que ya estaba sin leer al abrir).
  void _handleNotificationsUpdate(List<Map<String, dynamic>> notifications) {
    final currentIds = notifications.map((n) => n['id'] as String).toSet();

    if (!_notificationsBaselineSet) {
      _seenNotificationIds = currentIds;
      _notificationsBaselineSet = true;
      return;
    }

    for (final notification in notifications) {
      final id = notification['id'] as String;
      if (_seenNotificationIds.contains(id)) continue;
      _seenNotificationIds.add(id);
      if (notification['is_read'] == true) continue;
      LocalNotificationService.instance.show(
        id: id.hashCode,
        title: 'HeartCoin',
        body: NotificationService.instance.messageFor(notification),
      );
    }
  }

  Future<void> _loadBlockedIds() async {
    final blocked = await BlockService.instance.fetchBlockedIds();
    if (mounted) setState(() => _blockedIds = blocked);
  }

  Future<void> _loadMyProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _supabase
          .from('personal_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (mounted) setState(() => _myProfile = data);
    } catch (_) {
      // Si falla, el drawer simplemente muestra valores por defecto.
    }
  }

  @override
  void dispose() {
    _notificationsSub?.cancel();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _selectedTab) return;

    // El índice 0 (Home) se queda en esta misma pantalla.
    // Los demás navegan a sus pantallas correspondientes. Ajusta los
    // imports/clases si los nombres reales difieren de los que ya
    // tienes en tu proyecto (wallet_screen.dart, profile_screen.dart,
    // iniciativas_screen.dart, tu pantalla de búsqueda).
    switch (index) {
      case 1: // Buscar
        Navigator.of(context).pushNamed('/search');
        break;
      case 2: // HeartCoin / Wallet (botón central)
        Navigator.of(context).pushNamed('/wallet');
        break;
      case 3: // Tus acciones
        Navigator.of(context).pushNamed('/mis-acciones');
        break;
      case 4: // Perfil
        Navigator.of(context).pushNamed('/profile');
        break;
    }
  }

  void _onCreatePost() {
    // TODO: navegar a tu pantalla de creación de publicación.
    Navigator.of(context).pushNamed('/create-post');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.gris100,
      drawer: _AppDrawer(profile: _myProfile),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: NotificationService.instance.notificationsStream(),
              builder: (context, snapshot) {
                final hasUnread = (snapshot.data ?? []).any(
                  (n) => n['is_read'] == false,
                );
                return _TopBar(
                  userName: _myProfile?['full_name'] as String?,
                  hasUnreadNotifications: hasUnread,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  onNotificationsTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                );
              },
            ),
            Expanded(child: _buildFeed()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onCreatePost,
        backgroundColor: AppColors.primarioRojo,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedTab,
        onTap: (index) {
          _onTabTapped(index);
          setState(() => _selectedTab = index);
        },
      ),
    );
  }

  Widget _buildFeed() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _feedStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primarioRojo),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'No se pudieron cargar las publicaciones.',
              style: TextStyle(color: AppColors.gris600),
            ),
          );
        }

        final posts = (snapshot.data ?? [])
            .where((p) => !_blockedIds.contains(p['author_id']))
            .toList();
        if (posts.isEmpty) {
          return Center(
            child: Text(
              'Aún no hay publicaciones.\n¡Sé el primero en compartir algo!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gris600, fontSize: 14),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primarioRojo,
          onRefresh: () async => _loadMyProfile(),
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _PostCard(post: posts[index], onBlocked: _loadBlockedIds),
          ),
        );
      },
    );
  }
}

/// ============================================================
/// TOP BAR: menú lateral + logo + notificaciones
/// ============================================================
class _TopBar extends StatelessWidget {
  final String? userName;
  final bool hasUnreadNotifications;
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationsTap;

  const _TopBar({
    required this.userName,
    required this.hasUnreadNotifications,
    required this.onMenuTap,
    required this.onNotificationsTap,
  });

  String get _greeting {
    final name = userName?.trim();
    if (name == null || name.isEmpty) return 'Bienvenido a HeartCoin';
    final firstName = name.split(' ').first;
    return 'Bienvenido, $firstName';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primarioBlanco,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onMenuTap,
            child: Icon(
              Icons.menu_rounded,
              color: AppColors.primarioNegro,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _greeting,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primarioNegro,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onNotificationsTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primarioNegro,
                  size: 26,
                ),
                if (hasUnreadNotifications)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppColors.primarioRojo,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// MENÚ LATERAL DESLIZANTE
/// ============================================================
class _AppDrawer extends StatelessWidget {
  final Map<String, dynamic>? profile;

  const _AppDrawer({required this.profile});

  @override
  Widget build(BuildContext context) {
    final fullName = profile?['full_name'] as String? ?? 'Usuario';
    final email = profile?['email'] as String? ?? '';
    final avatarUrl = profile?['avatar_url'] as String?;

    return Drawer(
      backgroundColor: AppColors.primarioBlanco,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.gris200,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Icon(Icons.person, color: AppColors.gris600, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarioNegro,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.gris600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.gris200),
            const SizedBox(height: 8),
            _DrawerItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Mi wallet',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/wallet');
              },
            ),
            _DrawerItem(
              icon: Icons.how_to_vote_outlined,
              label: 'Votaciones',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/votaciones');
              },
            ),
            _DrawerItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Certificados',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/certificados');
              },
            ),
            _DrawerItem(
              icon: Icons.savings_outlined,
              label: 'Iniciativas de ahorro',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/iniciativas-ahorro');
              },
            ),
            _DrawerItem(
              icon: Icons.volunteer_activism_outlined,
              label: 'Iniciativas social',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/iniciativas-social');
              },
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Configuración',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/settings');
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmSignOut(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarioRojo,
                    foregroundColor: AppColors.primarioBlanco,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primarioRojo,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gris700),
      title: Text(
        label,
        style: TextStyle(
          color: AppColors.primarioNegro,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// ============================================================
/// TARJETA DE PUBLICACIÓN (estilo feed de Instagram, sin historias)
/// ============================================================
class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onBlocked;
  const _PostCard({required this.post, required this.onBlocked});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool? _liked; // null = aún no se sabe si el usuario le dio like

  @override
  void initState() {
    super.initState();
    _loadLikeState();
  }

  @override
  void didUpdateWidget(covariant _PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post['id'] != widget.post['id']) _loadLikeState();
  }

  Future<void> _loadLikeState() async {
    final liked = await SocialService.instance.hasLikedPost(
      widget.post['id'] as String,
    );
    if (mounted) setState(() => _liked = liked);
  }

  Future<void> _toggleLike() async {
    if (_liked == null) return;
    final wasLiked = _liked!;
    setState(() => _liked = !wasLiked);
    try {
      await SocialService.instance.toggleLikePost(widget.post['id'] as String);
    } catch (_) {
      if (mounted) setState(() => _liked = wasLiked);
    }
  }

  void _showOptions(String authorId, String authorName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primarioBlanco,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.primarioRojo),
                title: Text('Bloquear a $authorName'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Bloquear usuario'),
                      content: Text(
                        'Ya no verás publicaciones de $authorName y él/ella no podrá interactuar contigo. ¿Continuar?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primarioRojo,
                          ),
                          child: const Text('Bloquear'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  try {
                    await BlockService.instance.blockUser(authorId);
                    widget.onBlocked();
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No se pudo bloquear al usuario.'),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final authorId = post['author_id'] as String?;
    final authorName = post['author_name'] as String? ?? 'Usuario HeartCoin';
    final authorAvatar = post['author_avatar_url'] as String?;
    final imageUrl = post['image_url'] as String?;
    final caption = post['caption'] as String? ?? post['content'] as String?;
    final likesCount = (post['likes_count'] as num?)?.toInt() ?? 0;
    final commentsCount = (post['comments_count'] as num?)?.toInt() ?? 0;
    final liked = _liked ?? false;

    return Container(
      color: AppColors.primarioBlanco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado: avatar + nombre
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: authorId == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(userId: authorId),
                          ),
                        ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.gris200,
                    backgroundImage: authorAvatar != null
                        ? NetworkImage(authorAvatar)
                        : null,
                    child: authorAvatar == null
                        ? Icon(Icons.person, color: AppColors.gris600, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: authorId == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  UserProfileScreen(userId: authorId),
                            ),
                          ),
                    child: Text(
                      authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primarioNegro,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (authorId != null) ...[
                  FollowButton(targetUserId: authorId),
                  const SizedBox(width: 4),
                ],
                if (authorId != null)
                  GestureDetector(
                    onTap: () => _showOptions(authorId, authorName),
                    child: Icon(
                      Icons.more_vert,
                      color: AppColors.gris600,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),

          // Imagen de la publicación
          if (imageUrl != null)
            AspectRatio(
              aspectRatio: 1,
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

          // Acciones: like, comentario, compartir
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: _liked == null ? null : _toggleLike,
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked
                        ? AppColors.primarioRojo
                        : AppColors.primarioNegro,
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      showCommentsSheet(context, postId: post['id'] as String),
                  icon: Icon(
                    Icons.mode_comment_outlined,
                    color: AppColors.primarioNegro,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.send_outlined,
                    color: AppColors.primarioNegro,
                  ),
                ),
              ],
            ),
          ),

          // Contador de likes
          if (likesCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$likesCount me gusta',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primarioNegro,
                ),
              ),
            ),

          // Caption
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primarioNegro,
                  ),
                  children: [
                    TextSpan(
                      text: '$authorName  ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: caption),
                  ],
                ),
              ),
            ),

          // Comentarios
          if (commentsCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: GestureDetector(
                onTap: () =>
                    showCommentsSheet(context, postId: post['id'] as String),
                child: Text(
                  'Ver los $commentsCount comentarios',
                  style: TextStyle(fontSize: 13, color: AppColors.gris600),
                ),
              ),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// ============================================================
/// BOTTOM NAV BAR (réplica del diseño: pill blanco flotante,
/// 5 íconos, botón central elevado en rojo)
/// ============================================================
class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.primarioBlanco,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: AppColors.primarioNegro.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavIcon(
              icon: Icons.home_rounded,
              isSelected: selectedIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavIcon(
              icon: Icons.search_rounded,
              isSelected: selectedIndex == 1,
              onTap: () => onTap(1),
            ),
            _CenterNavIcon(onTap: () => onTap(2)),
            _NavIcon(
              icon: Icons.fact_check_outlined,
              isSelected: selectedIndex == 3,
              onTap: () => onTap(3),
            ),
            _NavIcon(
              icon: Icons.person_outline_rounded,
              isSelected: selectedIndex == 4,
              onTap: () => onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          size: 24,
          color: isSelected ? AppColors.primarioRojo : AppColors.gris600,
        ),
      ),
    );
  }
}

/// Botón central elevado (logo HeartCoin: corazón + moneda).
class _CenterNavIcon extends StatelessWidget {
  final VoidCallback onTap;
  const _CenterNavIcon({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: const Offset(0, -14),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primarioRojo,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primarioRojo.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.favorite, color: Colors.white, size: 26),
              Positioned(
                bottom: 12,
                child: Icon(
                  Icons.toll,
                  color: AppColors.primarioRojo,
                  size: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
