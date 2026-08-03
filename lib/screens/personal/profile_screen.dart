import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/posts_grid.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late final TabController _tabController;

  Map<String, dynamic>? _profile;
  int _postsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;

  List<Map<String, dynamic>> _myPosts = [];
  List<Map<String, dynamic>> _likedPosts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final profile = await _client
          .from('personal_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      final myPosts = await _client
          .from('publicaciones')
          .select()
          .eq('author_id', userId)
          .order('created_at', ascending: false);

      final likedRows = await _client
          .from('post_likes')
          .select('post_id, publicaciones(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final followersResponse = await _client
          .from('follows')
          .select('follower_id')
          .eq('followed_id', userId)
          .count();

      final followingResponse = await _client
          .from('follows')
          .select('followed_id')
          .eq('follower_id', userId)
          .count();

      final likedPosts = likedRows
          .map((row) => row['publicaciones'])
          .whereType<Map<String, dynamic>>()
          .toList();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _myPosts = myPosts.cast<Map<String, dynamic>>();
        _likedPosts = likedPosts;
        _postsCount = _myPosts.length;
        _followersCount = followersResponse.count;
        _followingCount = followingResponse.count;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _profile?['full_name'] as String? ?? 'Usuario HeartCoin';
    final avatarUrl = _profile?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Mi perfil'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            )
          : RefreshIndicator(
              color: AppColors.primarioRojo,
              onRefresh: _loadAll,
              child: NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        ClipOval(
                          child: Container(
                            width: 88,
                            height: 88,
                            color: AppColors.gris200,
                            child: avatarUrl != null
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.person,
                                      size: 44,
                                      color: AppColors.gris600,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 44,
                                    color: AppColors.gris600,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          fullName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarioNegro,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatColumn(label: 'Posts', value: _postsCount),
                            _StatDivider(),
                            _StatColumn(
                              label: 'Followers',
                              value: _followersCount,
                            ),
                            _StatDivider(),
                            _StatColumn(
                              label: 'Follows',
                              value: _followingCount,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primarioRojo,
                        unselectedLabelColor: AppColors.gris600,
                        indicatorColor: AppColors.primarioRojo,
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_on), text: 'Publicaciones'),
                          Tab(
                            icon: Icon(Icons.favorite_border),
                            text: 'Me gusta',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    PostsGrid(posts: _myPosts),
                    PostsGrid(posts: _likedPosts),
                  ],
                ),
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

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.primarioBlanco, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
