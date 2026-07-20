import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../widgets/iniciativa_widgets.dart';
import 'create_org_iniciativa_screen.dart';
import 'edit_org_iniciativa_screen.dart';
import 'iniciativa_detail_screen.dart';
import 'iniciativa_qr_screen.dart';

/// Iniciativas (Voluntariado/Crowdfunding/Social) creadas por la
/// organización, con su flujo Borrador -> Votación -> Activa.
class OrgIniciativasScreen extends StatefulWidget {
  const OrgIniciativasScreen({super.key});

  @override
  State<OrgIniciativasScreen> createState() => _OrgIniciativasScreenState();
}

class _OrgIniciativasScreenState extends State<OrgIniciativasScreen> {
  static const _orgCategories = ['Voluntariado', 'Crowdfunding', 'Social'];

  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();

  String? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _ownIniciativas(List<Map<String, dynamic>> all) {
    final userId = _client.auth.currentUser?.id;
    return all
        .where(
          (i) =>
              i['author_id'] == userId &&
              _orgCategories.contains(i['category']),
        )
        .toList();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> list) {
    final query = _searchController.text.trim().toLowerCase();
    return list.where((i) {
      if (_statusFilter != null && i['status'] != _statusFilter) return false;
      if (query.isEmpty) return true;
      final title = (i['title'] as String? ?? '').toLowerCase();
      return title.contains(query);
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
        title: const Text('Mis iniciativas'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const CreateOrgIniciativaScreen(),
            ),
          );
          if (created == true && mounted) setState(() {});
        },
        backgroundColor: AppColors.primarioRojo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _client.from('iniciativas').stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            );
          }

          final own = _ownIniciativas(snapshot.data ?? []);
          final filtered = _applyFilters(own);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _CounterCard(iniciativas: own),
              const SizedBox(height: 16),
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
                    hintText: 'Buscar iniciativas...',
                    hintStyle: TextStyle(color: AppColors.gris600),
                    prefixIcon: Icon(Icons.search, color: AppColors.gris600),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    AppChip(
                      label: 'Todas',
                      selected: _statusFilter == null,
                      onTap: () => setState(() => _statusFilter = null),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Borrador',
                      selected: _statusFilter == 'borrador',
                      onTap: () => setState(() => _statusFilter = 'borrador'),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Votación',
                      selected: _statusFilter == 'votacion',
                      onTap: () => setState(() => _statusFilter = 'votacion'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No tienes iniciativas que coincidan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.gris600),
                    ),
                  ),
                )
              else
                ...filtered.map(
                  (iniciativa) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OrgIniciativaCard(iniciativa: iniciativa),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final List<Map<String, dynamic>> iniciativas;
  const _CounterCard({required this.iniciativas});

  @override
  Widget build(BuildContext context) {
    final total = iniciativas.length;
    final enVotacion = iniciativas
        .where((i) => i['status'] == 'votacion')
        .length;
    final activas = iniciativas.where((i) => i['status'] == 'activa').length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primarioBlanco,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CounterItem(label: 'Total', value: total),
          ),
          Container(width: 1, height: 36, color: AppColors.gris200),
          Expanded(
            child: _CounterItem(label: 'En Votación', value: enVotacion),
          ),
          Container(width: 1, height: 36, color: AppColors.gris200),
          Expanded(
            child: _CounterItem(label: 'Activas', value: activas),
          ),
        ],
      ),
    );
  }
}

class _CounterItem extends StatelessWidget {
  final String label;
  final int value;
  const _CounterItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primarioNegro,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.gris600)),
      ],
    );
  }
}

class _OrgIniciativaCard extends StatelessWidget {
  final Map<String, dynamic> iniciativa;
  const _OrgIniciativaCard({required this.iniciativa});

  static const _statusLabels = {
    'borrador': 'Borrador',
    'votacion': 'En votación',
    'activa': 'Activa',
  };

  static const _statusColors = {
    'borrador': AppColors.gris600,
    'votacion': AppColors.secundarioNaranja,
    'activa': AppColors.secundarioVerde,
  };

  String _remainingLabel() {
    final endsAt = iniciativa['voting_ends_at'] as String?;
    if (endsAt == null) return 'Sin fecha límite';
    final date = DateTime.tryParse(endsAt);
    if (date == null) return 'Sin fecha límite';
    final remaining = date.toUtc().difference(DateTime.now().toUtc());
    if (remaining.isNegative) return 'Votación cerrada';
    if (remaining.inDays >= 1) return '${remaining.inDays} días restantes';
    if (remaining.inHours >= 1) return '${remaining.inHours} horas restantes';
    return 'Menos de una hora restante';
  }

  @override
  Widget build(BuildContext context) {
    final status = iniciativa['status'] as String? ?? 'borrador';
    final title = iniciativa['title'] as String? ?? 'Iniciativa';
    final votesCount = (iniciativa['votes_count'] as num?)?.toInt() ?? 0;
    final votesGoal = (iniciativa['votes_goal'] as num?)?.toInt();
    final id = iniciativa['id'] as String?;

    final String progressLabel;
    final double? progressFraction;
    if (status == 'votacion' && votesGoal != null && votesGoal > 0) {
      final percent = ((votesCount / votesGoal) * 100).clamp(0, 100).round();
      progressLabel = '$percent% aprobado';
      progressFraction = (votesCount / votesGoal).clamp(0.0, 1.0);
    } else if (status == 'activa') {
      progressLabel = 'Aprobada';
      progressFraction = 1.0;
    } else {
      progressLabel = 'Sin iniciar votación';
      progressFraction = null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarioBlanco,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (_statusColors[status] ?? AppColors.gris600).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _statusLabels[status] ?? status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _statusColors[status] ?? AppColors.gris600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (progressFraction != null) ...[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progressFraction,
                      minHeight: 6,
                      backgroundColor: AppColors.gris200,
                      color: _statusColors[status] ?? AppColors.primarioRojo,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                progressLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gris700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: AppColors.gris600),
              const SizedBox(width: 4),
              Text(
                _remainingLabel(),
                style: TextStyle(fontSize: 12, color: AppColors.gris600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          IniciativaDetailScreen(iniciativa: iniciativa),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primarioRojo,
                    side: const BorderSide(color: AppColors.primarioRojo),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Ver'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          EditOrgIniciativaScreen(iniciativa: iniciativa),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gris700,
                    side: BorderSide(color: AppColors.gris300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Editar'),
                ),
              ),
            ],
          ),
          if (id != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IniciativaQrScreen(
                      iniciativaId: id,
                      iniciativaTitle: title,
                    ),
                  ),
                ),
                icon: const Icon(Icons.qr_code, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primarioRojo,
                  side: const BorderSide(color: AppColors.primarioRojo),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                label: const Text('Mostrar QR'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
