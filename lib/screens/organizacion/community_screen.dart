import 'package:flutter/material.dart';

import '../../services/organizacion/community_service.dart';
import '../../theme/app_colors.dart';

/// Lista de usuarios que han participado votando en votaciones o
/// apoyando iniciativas (rol organización).
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _participants = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final participants = await CommunityService.instance.loadParticipants();
      if (mounted) setState(() => _participants = participants);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _participants;
    return _participants.where((p) {
      final name = (p['full_name'] as String? ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Comunidad'),
      ),
      body: RefreshIndicator(
        color: AppColors.primarioRojo,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.primarioBlanco,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gris300),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre...',
                  hintStyle: TextStyle(color: AppColors.gris600),
                  prefixIcon: Icon(Icons.search, color: AppColors.gris600),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primarioRojo,
                  ),
                ),
              )
            else if (_filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Aún no hay usuarios que hayan participado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.gris600),
                  ),
                ),
              )
            else
              ..._filtered.map(
                (participant) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ParticipantTile(participant: participant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Map<String, dynamic> participant;
  const _ParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    final name = participant['full_name'] as String? ?? 'Usuario HeartCoin';
    final city = participant['city'] as String?;
    final avatarUrl = participant['avatar_url'] as String?;
    final count = participant['participation_count'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarioBlanco,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.gris200,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(Icons.person, color: AppColors.gris600)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primarioNegro,
                  ),
                ),
                if (city != null && city.isNotEmpty)
                  Text(
                    city,
                    style: TextStyle(fontSize: 12, color: AppColors.gris600),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.rojoClaro1.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count participaciones',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primarioRojo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
