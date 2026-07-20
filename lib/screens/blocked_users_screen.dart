import 'package:flutter/material.dart';

import '../services/block_service.dart';
import '../theme/app_colors.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _blocked = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final blocked = await BlockService.instance.fetchBlockedProfiles();
      if (mounted) setState(() => _blocked = blocked);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblock(String userId) async {
    setState(() => _blocked.removeWhere((p) => p['id'] == userId));
    try {
      await BlockService.instance.unblockUser(userId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo desbloquear. Intenta de nuevo.'),
          ),
        );
        _load();
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
        title: const Text('Usuarios bloqueados'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            )
          : _blocked.isEmpty
          ? Center(
              child: Text(
                'No has bloqueado a nadie.',
                style: TextStyle(color: AppColors.gris600),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _blocked.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final profile = _blocked[index];
                final fullName =
                    profile['full_name'] as String? ?? 'Usuario HeartCoin';
                final avatarUrl = profile['avatar_url'] as String?;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarioBlanco,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.gris200,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Icon(Icons.person, color: AppColors.gris600)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fullName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarioNegro,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _unblock(profile['id'] as String),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primarioRojo,
                          side: const BorderSide(color: AppColors.primarioRojo),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Desbloquear'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
