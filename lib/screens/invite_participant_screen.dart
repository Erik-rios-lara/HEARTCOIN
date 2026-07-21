import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/iniciativa_participants_service.dart';
import '../theme/app_colors.dart';

/// Busca un usuario por nombre e invítalo como participante de una
/// iniciativa de Ahorro. Devuelve `true` por Navigator.pop si se invitó
/// a alguien.
class InviteParticipantScreen extends StatefulWidget {
  final String iniciativaId;
  final Set<String> excludedUserIds;

  const InviteParticipantScreen({
    super.key,
    required this.iniciativaId,
    required this.excludedUserIds,
  });

  @override
  State<InviteParticipantScreen> createState() =>
      _InviteParticipantScreenState();
}

class _InviteParticipantScreenState extends State<InviteParticipantScreen> {
  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _isSearching = false;
  bool _isInviting = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final rows = await _client
          .from('personal_profiles')
          .select('id, full_name, avatar_url')
          .ilike('full_name', '%$trimmed%')
          .limit(20);
      if (!mounted) return;
      final myId = _client.auth.currentUser?.id;
      setState(() {
        _results = (rows as List)
            .cast<Map<String, dynamic>>()
            .where(
              (row) =>
                  row['id'] != myId &&
                  !widget.excludedUserIds.contains(row['id']),
            )
            .toList();
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _invite(Map<String, dynamic> profile) async {
    if (_isInviting) return;
    setState(() => _isInviting = true);
    try {
      await IniciativaParticipantsService.instance.inviteParticipant(
        iniciativaId: widget.iniciativaId,
        userId: profile['id'] as String,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo invitar a este participante.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
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
        title: const Text('Invitar participante'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.primarioBlanco,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_isSearching) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? 'Escribe un nombre para buscar.'
                          : 'No se encontraron personas con ese nombre.',
                      style: TextStyle(color: AppColors.gris600),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppColors.gris200),
                    itemBuilder: (context, index) {
                      final profile = _results[index];
                      final avatarUrl = profile['avatar_url'] as String?;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.gris200,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Icon(Icons.person, color: AppColors.gris600)
                              : null,
                        ),
                        title: Text(
                          profile['full_name'] as String? ?? 'Usuario',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarioNegro,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: _isInviting ? null : () => _invite(profile),
                          child: const Text(
                            'Invitar',
                            style: TextStyle(
                              color: AppColors.primarioRojo,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
