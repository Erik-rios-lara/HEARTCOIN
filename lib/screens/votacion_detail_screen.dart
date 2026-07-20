import 'package:flutter/material.dart';

import '../services/votacion_comments_service.dart';
import '../services/votaciones_service.dart';
import '../theme/app_colors.dart';
import '../widgets/save_button.dart';

enum _DetailTab { detalles, comentarios, presupuesto }

class VotacionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> votacion;
  const VotacionDetailScreen({super.key, required this.votacion});

  @override
  State<VotacionDetailScreen> createState() => _VotacionDetailScreenState();
}

class _VotacionDetailScreenState extends State<VotacionDetailScreen> {
  bool? _hasVoted;
  bool _isVoting = false;
  _DetailTab _tab = _DetailTab.detalles;

  @override
  void initState() {
    super.initState();
    _loadVoteState();
  }

  Future<void> _loadVoteState() async {
    final voted = await VotacionesService.instance.hasVoted(
      widget.votacion['id'] as String,
    );
    if (mounted) setState(() => _hasVoted = voted);
  }

  Future<void> _vote() async {
    if (_isVoting || (_hasVoted ?? true)) return;
    setState(() => _isVoting = true);
    try {
      await VotacionesService.instance.vote(widget.votacion['id'] as String);
      if (mounted) setState(() => _hasVoted = true);
    } on AlreadyVotedException {
      if (mounted) setState(() => _hasVoted = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo registrar tu voto. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'Voluntariado':
        return Icons.groups;
      case 'Crowdfunding':
        return Icons.volunteer_activism;
      case 'Social':
        return Icons.diversity_3;
      case 'Ahorro':
        return Icons.savings;
      default:
        return Icons.favorite;
    }
  }

  String _statusLabel(String? endsAt) {
    final date = endsAt != null ? DateTime.tryParse(endsAt) : null;
    if (date != null && date.toUtc().isBefore(DateTime.now().toUtc())) {
      return 'Votación cerrada';
    }
    return 'En proceso de votación';
  }

  String _remainingLabel(String? endsAt) {
    if (endsAt == null) return 'Sin fecha límite';
    final date = DateTime.tryParse(endsAt);
    if (date == null) return 'Sin fecha límite';
    final remaining = date.toUtc().difference(DateTime.now().toUtc());
    if (remaining.isNegative) return 'Votación cerrada.';

    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    if (days >= 1) return '$days días $hours horas.';
    if (remaining.inHours >= 1) return '${remaining.inHours} horas.';
    return 'Menos de una hora.';
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

          final type = votacion['type'] as String? ?? '';
          final title = votacion['title'] as String? ?? 'Iniciativa';
          final description = votacion['description'] as String?;
          final hcReward = (votacion['hc_reward'] as num?)?.toInt() ?? 0;
          final votesCount = (votacion['votes_count'] as num?)?.toInt() ?? 0;
          final votesGoal = (votacion['votes_goal'] as num?)?.toInt() ?? 1;
          final progress = votesGoal > 0
              ? (votesCount / votesGoal).clamp(0.0, 1.0)
              : 0.0;
          final progressPercent = (progress * 100).round();
          final endsAt = votacion['ends_at'] as String?;
          final voted = _hasVoted ?? false;
          final votacionId = votacion['id'] as String;
          final budgetItems =
              (votacion['budget_items'] as List<dynamic>?) ?? [];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  votacionId: votacionId,
                  statusLabel: _statusLabel(endsAt),
                  title: title,
                  type: type,
                  typeIcon: _iconForType(type),
                  hcReward: hcReward,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Votación',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primarioNegro,
                            ),
                          ),
                          Text(
                            '$progressPercent%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gris700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: AppColors.gris300,
                          color: AppColors.secundarioVerde,
                        ),
                      ),
                      const SizedBox(height: 16),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _StatCard(
                                backgroundColor: AppColors.primarioRojo,
                                icon: Icons.how_to_vote,
                                iconColor: Colors.white,
                                title: '$votesCount votos recibidos',
                                titleColor: Colors.white,
                                subtitle: 'Necesita: $votesGoal votos',
                                subtitleColor: Colors.white.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                backgroundColor: AppColors.gris200,
                                icon: Icons.timelapse,
                                iconColor: AppColors.primarioNegro,
                                title: 'Tiempo Restante',
                                titleColor: AppColors.primarioNegro,
                                subtitle: _remainingLabel(endsAt),
                                subtitleColor: AppColors.gris700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _TabRow(
                        selected: _tab,
                        onSelected: (t) => setState(() => _tab = t),
                      ),
                      const SizedBox(height: 16),
                      _TabContent(
                        tab: _tab,
                        description: description,
                        votacionId: votacionId,
                        budgetItems: budgetItems,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (_hasVoted == null || voted || _isVoting)
                              ? null
                              : _vote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: voted
                                ? AppColors.gris300
                                : AppColors.primarioRojo,
                            foregroundColor: voted
                                ? AppColors.gris700
                                : Colors.white,
                            disabledBackgroundColor: AppColors.gris300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isVoting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  voted
                                      ? 'Ya votaste'
                                      : 'Votar por esta iniciativa',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
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

class _Header extends StatelessWidget {
  final String votacionId;
  final String statusLabel;
  final String title;
  final String type;
  final IconData typeIcon;
  final int hcReward;

  const _Header({
    required this.votacionId,
    required this.statusLabel,
    required this.title,
    required this.type,
    required this.typeIcon,
    required this.hcReward,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primarioNegro, AppColors.rojoOscuro2],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleIconButton(
                        icon: Icons.chevron_left,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      SaveButton(itemType: 'votacion', itemId: votacionId),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: -40,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primarioRojo, AppColors.rojoOscuro1],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primarioNegro.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            typeIcon,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            type,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Posible\nRecompensa',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$hcReward',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String subtitle;
  final Color subtitleColor;

  const _StatCard({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.subtitle,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor)),
        ],
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  final _DetailTab selected;
  final ValueChanged<_DetailTab> onSelected;

  const _TabRow({required this.selected, required this.onSelected});

  static const _labels = {
    _DetailTab.detalles: 'Detalles',
    _DetailTab.comentarios: 'Comentarios',
    _DetailTab.presupuesto: 'Presupuesto',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _DetailTab.values.map((tab) {
        final isSelected = tab == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => onSelected(tab),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarioRojo : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _labels[tab]!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.gris700,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TabContent extends StatelessWidget {
  final _DetailTab tab;
  final String? description;
  final String votacionId;
  final List<dynamic> budgetItems;

  const _TabContent({
    required this.tab,
    required this.description,
    required this.votacionId,
    required this.budgetItems,
  });

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case _DetailTab.detalles:
        return Text(
          (description != null && description!.isNotEmpty)
              ? description!
              : 'Esta iniciativa aún no tiene una descripción detallada.',
          style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.gris800),
        );
      case _DetailTab.comentarios:
        return _ComentariosTab(votacionId: votacionId);
      case _DetailTab.presupuesto:
        return _PresupuestoTab(items: budgetItems);
    }
  }
}

class _ComentariosTab extends StatefulWidget {
  final String votacionId;
  const _ComentariosTab({required this.votacionId});

  @override
  State<_ComentariosTab> createState() => _ComentariosTabState();
}

class _ComentariosTabState extends State<_ComentariosTab> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await VotacionCommentsService.instance.addComment(
        votacionId: widget.votacionId,
        content: text,
      );
      _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el comentario.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Escribe un comentario...',
                  filled: true,
                  fillColor: AppColors.gris100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSending ? null : _send,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: AppColors.primarioRojo,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: VotacionCommentsService.instance.commentsStream(
            widget.votacionId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primarioRojo,
                  ),
                ),
              );
            }

            final comments = snapshot.data ?? [];
            if (comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Aún no hay comentarios. Sé el primero.',
                    style: TextStyle(color: AppColors.gris600),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) =>
                  _ComentarioRow(comment: comments[index]),
            );
          },
        ),
      ],
    );
  }
}

class _ComentarioRow extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _ComentarioRow({required this.comment});

  @override
  Widget build(BuildContext context) {
    final authorName = comment['author_name'] as String? ?? 'Usuario HeartCoin';
    final authorAvatar = comment['author_avatar_url'] as String?;
    final content = comment['content'] as String? ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.gris200,
          backgroundImage: authorAvatar != null
              ? NetworkImage(authorAvatar)
              : null,
          child: authorAvatar == null
              ? Icon(Icons.person, size: 16, color: AppColors.gris600)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: AppColors.primarioNegro),
              children: [
                TextSpan(
                  text: '$authorName  ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: content),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PresupuestoTab extends StatelessWidget {
  final List<dynamic> items;
  const _PresupuestoTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Esta votación aún no tiene un desglose de presupuesto.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gris600),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((raw) {
        final item = raw as Map<String, dynamic>;
        final label = item['label'] as String? ?? '';
        final percentage = ((item['percentage'] as num?)?.toDouble() ?? 0)
            .clamp(0, 100);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primarioNegro,
                    ),
                  ),
                  Text(
                    '${percentage.round()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gris700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 8,
                  backgroundColor: AppColors.gris200,
                  color: AppColors.primarioRojo,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
