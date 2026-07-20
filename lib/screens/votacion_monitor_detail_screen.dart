import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/votaciones_service.dart';
import '../theme/app_colors.dart';

/// Detalle de una votación desde el Monitor de votaciones (rol
/// Organización): progreso, tasa de aprobación, participación y
/// evolución de votos en el tiempo.
class VotacionMonitorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> votacion;
  const VotacionMonitorDetailScreen({super.key, required this.votacion});

  @override
  State<VotacionMonitorDetailScreen> createState() =>
      _VotacionMonitorDetailScreenState();
}

class _VotacionMonitorDetailScreenState
    extends State<VotacionMonitorDetailScreen> {
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  int _totalUsers = 0;
  List<_DailyVotes> _evolution = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final votacionId = widget.votacion['id'] as String;

      final usersResponse = await _client
          .from('personal_profiles')
          .select('id')
          .count();

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
      final sortedDays = perDay.keys.toList()..sort();
      var cumulative = 0;
      final evolution = <_DailyVotes>[];
      for (final day in sortedDays) {
        cumulative += perDay[day]!;
        evolution.add(_DailyVotes(day: day, cumulativeVotes: cumulative));
      }

      if (!mounted) return;
      setState(() {
        _totalUsers = usersResponse.count;
        _evolution = evolution;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _remainingLabel(String? endsAt) {
    if (endsAt == null) return 'Sin fecha límite';
    final date = DateTime.tryParse(endsAt);
    if (date == null) return 'Sin fecha límite';
    final remaining = date.toUtc().difference(DateTime.now().toUtc());
    if (remaining.isNegative) return 'Votación cerrada';
    if (remaining.inDays >= 1) {
      final hours = remaining.inHours % 24;
      return '${remaining.inDays} días $hours hrs';
    }
    if (remaining.inHours >= 1) return '${remaining.inHours} hrs';
    return 'Menos de una hora';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: VotacionesService.instance.votacionesStream(),
        initialData: [widget.votacion],
        builder: (context, snapshot) {
          final votacion = (snapshot.data ?? [])
              .cast<Map<String, dynamic>>()
              .where((v) => v['id'] == widget.votacion['id'])
              .fold<Map<String, dynamic>>(widget.votacion, (_, v) => v);

          final title = votacion['title'] as String? ?? 'Votación';
          final votesCount = (votacion['votes_count'] as num?)?.toInt() ?? 0;
          final votesGoal = (votacion['votes_goal'] as num?)?.toInt() ?? 1;
          final endsAt = votacion['ends_at'] as String?;
          final endDate = endsAt != null ? DateTime.tryParse(endsAt) : null;
          final isClosed =
              endDate != null &&
              endDate.toUtc().isBefore(DateTime.now().toUtc());

          final approvalRate = votesGoal > 0
              ? ((votesCount / votesGoal) * 100).clamp(0, 100).round()
              : 0;
          final participationRate = _totalUsers > 0
              ? ((votesCount / _totalUsers) * 100).clamp(0, 100).round()
              : 0;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.primarioNegro,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primarioNegro,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isClosed
                        ? AppColors.secundarioVerde
                        : AppColors.secundarioNaranja,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.how_to_vote,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isClosed
                                  ? 'Votación Cerrada'
                                  : 'Votación en Proceso',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                                children: [
                                  const TextSpan(text: 'Tiempo restante:  '),
                                  TextSpan(
                                    text: _remainingLabel(endsAt),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                                children: [
                                  const TextSpan(text: 'Progreso: '),
                                  TextSpan(
                                    text:
                                        '$votesCount/$votesGoal votos necesarios',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        icon: Icons.check_circle_outline,
                        label: 'Tasa de Aprobación',
                        value: '$approvalRate%',
                        valueColor: AppColors.secundarioVerde,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        icon: Icons.groups_outlined,
                        label: 'Participación',
                        value: '$participationRate%',
                        valueColor: AppColors.secundarioAzul,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primarioBlanco,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evolución votación',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primarioNegro,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$votesCount',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primarioRojo,
                        ),
                      ),
                      Text(
                        'Votos',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.gris600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primarioRojo,
                            ),
                          ),
                        )
                      else if (_evolution.length < 2)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              'Aún no hay suficientes votos para mostrar una evolución.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.gris600),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 160,
                          child: _LineChart(points: _evolution),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gris200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primarioNegro, size: 20),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyVotes {
  final DateTime day;
  final int cumulativeVotes;
  const _DailyVotes({required this.day, required this.cumulativeVotes});
}

class _LineChart extends StatelessWidget {
  final List<_DailyVotes> points;
  const _LineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LineChartPainter(points: points),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_DailyVotes> points;
  _LineChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = points
        .map((p) => p.cumulativeVotes)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final minValue = 0.0;
    final range = (maxValue - minValue) == 0 ? 1 : (maxValue - minValue);

    const leftPadding = 32.0;
    const bottomPadding = 4.0;
    final chartWidth = size.width - leftPadding;
    final chartHeight = size.height - bottomPadding;

    final gridPaint = Paint()
      ..color = AppColors.gris200
      ..strokeWidth = 1;
    final textStyle = TextStyle(fontSize: 10, color: AppColors.gris600);

    for (var i = 0; i <= 2; i++) {
      final y = chartHeight - (chartHeight * i / 2);
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      final label = (minValue + (range * i / 2)).round().toString();
      final painter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(0, y - painter.height / 2));
    }

    final linePaint = Paint()
      ..color = AppColors.primarioRojo
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = AppColors.primarioRojo;

    final offsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x =
          leftPadding +
          (points.length == 1
              ? chartWidth / 2
              : chartWidth * i / (points.length - 1));
      final normalized = (points[i].cumulativeVotes - minValue) / range;
      final y = chartHeight - (chartHeight * normalized);
      offsets.add(Offset(x, y));
    }

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final offset in offsets.skip(1)) {
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(path, linePaint);

    for (final offset in offsets) {
      canvas.drawCircle(offset, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
