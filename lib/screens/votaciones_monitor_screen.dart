import 'package:flutter/material.dart';

import '../services/votaciones_service.dart';
import '../theme/app_colors.dart';
import '../widgets/iniciativa_widgets.dart';
import 'votacion_monitor_detail_screen.dart';

enum _MonitorSort { masVotados, masRecientes }

class VotacionesMonitorScreen extends StatefulWidget {
  const VotacionesMonitorScreen({super.key});

  @override
  State<VotacionesMonitorScreen> createState() =>
      _VotacionesMonitorScreenState();
}

class _VotacionesMonitorScreenState extends State<VotacionesMonitorScreen> {
  static const _categories = [
    'Voluntariado',
    'Crowdfunding',
    'Social',
    'Ahorro',
  ];

  String? _selectedCategory;
  _MonitorSort _sort = _MonitorSort.masVotados;

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> source) {
    var list = source.where((v) {
      if (_selectedCategory == null) return true;
      return v['type'] == _selectedCategory;
    }).toList();

    switch (_sort) {
      case _MonitorSort.masVotados:
        list.sort(
          (a, b) => ((b['votes_count'] as num?) ?? 0).compareTo(
            (a['votes_count'] as num?) ?? 0,
          ),
        );
        break;
      case _MonitorSort.masRecientes:
        list.sort(
          (a, b) => (b['created_at'] as String? ?? '').compareTo(
            a['created_at'] as String? ?? '',
          ),
        );
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Monitor de votaciones'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: VotacionesService.instance.votacionesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            );
          }

          final votaciones = _applyFilters(snapshot.data ?? []);
          final maxVotes = votaciones.isEmpty
              ? 1
              : votaciones
                    .map((v) => (v['votes_count'] as num?)?.toInt() ?? 0)
                    .reduce((a, b) => a > b ? a : b);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    AppChip(
                      label: 'Todas',
                      selected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    const SizedBox(width: 8),
                    for (final category in _categories) ...[
                      AppChip(
                        label: category,
                        selected: _selectedCategory == category,
                        onTap: () =>
                            setState(() => _selectedCategory = category),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    AppChip(
                      label: 'Más votados',
                      selected: _sort == _MonitorSort.masVotados,
                      onTap: () =>
                          setState(() => _sort = _MonitorSort.masVotados),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Más recientes',
                      selected: _sort == _MonitorSort.masRecientes,
                      onTap: () =>
                          setState(() => _sort = _MonitorSort.masRecientes),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (votaciones.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No hay votaciones que coincidan con el filtro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.gris600),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primarioBlanco,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < votaciones.length; i++) ...[
                        _RankingRow(
                          rank: i + 1,
                          votacion: votaciones[i],
                          maxVotes: maxVotes,
                        ),
                        if (i != votaciones.length - 1)
                          const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> votacion;
  final int maxVotes;

  const _RankingRow({
    required this.rank,
    required this.votacion,
    required this.maxVotes,
  });

  @override
  Widget build(BuildContext context) {
    final title = votacion['title'] as String? ?? 'Votación';
    final foundation = votacion['foundation_name'] as String? ?? '';
    final votesCount = (votacion['votes_count'] as num?)?.toInt() ?? 0;
    final fraction = maxVotes > 0 ? votesCount / maxVotes : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VotacionMonitorDetailScreen(votacion: votacion),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gris600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarioNegro,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$votesCount votos',
                  style: TextStyle(fontSize: 12, color: AppColors.gris600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (foundation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        foundation,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gris600,
                        ),
                      ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      height: 10,
                      color: AppColors.gris200,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fraction.clamp(0.02, 1.0),
                        child: Container(
                          height: 10,
                          color: AppColors.primarioRojo,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
