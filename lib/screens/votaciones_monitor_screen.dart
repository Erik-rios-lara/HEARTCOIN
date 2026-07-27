import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/votaciones_service.dart';
import '../theme/app_colors.dart';

/// Colores del gráfico de barras (se repiten en ciclo por cada barra),
/// igual que en el mockup: gris / verde-lima / cian.
const _barColors = [
  Color(0xFF58585A),
  Color(0xFFC4E538),
  Color(0xFF4AD6D6),
];

class VotacionesMonitorScreen extends StatefulWidget {
  const VotacionesMonitorScreen({super.key});

  @override
  State<VotacionesMonitorScreen> createState() =>
      _VotacionesMonitorScreenState();
}

class _VotacionesMonitorScreenState extends State<VotacionesMonitorScreen> {
  final _client = Supabase.instance.client;

  String? _selectedVotacionId;
  bool _isLoadingVotes = false;
  List<_DailyVotes> _dailyVotes = [];

  Future<void> _loadDailyVotes(String votacionId) async {
    setState(() => _isLoadingVotes = true);
    try {
      final votes = await _client
          .from('votacion_votes')
          .select('created_at')
          .eq('votacion_id', votacionId)
          .order('created_at');

      final perDay = <DateTime, int>{};
      for (final row in votes) {
        final createdAt = DateTime.tryParse(row['created_at'] as String);
        if (createdAt == null) continue;
        final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
        perDay[day] = (perDay[day] ?? 0) + 1;
      }

      final today = DateTime.now();
      final last7Days = [
        for (var i = 6; i >= 0; i--)
          DateTime(today.year, today.month, today.day - i),
      ];

      final daily = [
        for (final day in last7Days)
          _DailyVotes(day: day, votes: perDay[day] ?? 0),
      ];

      if (!mounted) return;
      setState(() => _dailyVotes = daily);
    } finally {
      if (mounted) setState(() => _isLoadingVotes = false);
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

          final votaciones = [...snapshot.data ?? []]
            ..sort(
              (a, b) => (b['created_at'] as String? ?? '').compareTo(
                a['created_at'] as String? ?? '',
              ),
            );

          if (votaciones.isEmpty) {
            return Center(
              child: Text(
                'Aún no hay votaciones registradas.',
                style: TextStyle(color: AppColors.gris600),
              ),
            );
          }

          final selectedId =
              (_selectedVotacionId != null &&
                  votaciones.any((v) => v['id'] == _selectedVotacionId))
              ? _selectedVotacionId
              : votaciones.first['id'] as String;

          if (_selectedVotacionId != selectedId) {
            _selectedVotacionId = selectedId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadDailyVotes(selectedId as String);
            });
          }

          final selected = votaciones.firstWhere(
            (v) => v['id'] == selectedId,
          );
          final title = selected['title'] as String? ?? 'Votación';
          final votesCount = (selected['votes_count'] as num?)?.toInt() ?? 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarioBlanco,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedId as String,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.primarioNegro,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primarioNegro,
                    ),
                    items: votaciones
                        .map(
                          (v) => DropdownMenuItem<String>(
                            value: v['id'] as String,
                            child: Text(
                              v['title'] as String? ?? 'Votación',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedVotacionId = value);
                      _loadDailyVotes(value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primarioBlanco,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primarioNegro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$votesCount votos totales',
                      style: TextStyle(fontSize: 12, color: AppColors.gris600),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingVotes)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primarioRojo,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 200,
                        child: _BarChart(points: _dailyVotes),
                      ),
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

class _DailyVotes {
  final DateTime day;
  final int votes;
  const _DailyVotes({required this.day, required this.votes});
}

class _BarChart extends StatelessWidget {
  final List<_DailyVotes> points;
  const _BarChart({required this.points});

  static const _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final maxVotes = points.isEmpty
        ? 1
        : points
              .map((p) => p.votes)
              .reduce((a, b) => a > b ? a : b)
              .clamp(1, 1 << 30);

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < points.length; i++) ...[
                if (i != 0) const SizedBox(width: 8),
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: (points[i].votes / maxVotes).clamp(
                      points[i].votes == 0 ? 0.02 : 0.08,
                      1.0,
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _barColors[i % _barColors.length],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < points.length; i++) ...[
              if (i != 0) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _weekdayLabels[points[i].day.weekday - 1],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.gris600),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
