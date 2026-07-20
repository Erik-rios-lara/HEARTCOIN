import 'package:flutter/material.dart';

import '../services/checkin_service.dart';
import '../services/iniciativas_service.dart';
import '../theme/app_colors.dart';
import '../widgets/follow_button.dart';
import '../widgets/save_button.dart';
import 'checkin_scanner_screen.dart';

enum _DetailTab { detalles, comentarios, presupuesto }

class IniciativaDetailScreen extends StatefulWidget {
  final Map<String, dynamic> iniciativa;
  const IniciativaDetailScreen({super.key, required this.iniciativa});

  @override
  State<IniciativaDetailScreen> createState() => _IniciativaDetailScreenState();
}

class _IniciativaDetailScreenState extends State<IniciativaDetailScreen> {
  bool? _hasVoted;
  bool _isVoting = false;
  bool? _hasCheckedIn;
  bool _isCheckingIn = false;
  _DetailTab _tab = _DetailTab.detalles;

  @override
  void initState() {
    super.initState();
    _loadVoteState();
    _loadCheckinState();
  }

  Future<void> _loadVoteState() async {
    final voted = await IniciativasService.instance.hasVoted(
      widget.iniciativa['id'] as String,
    );
    if (mounted) setState(() => _hasVoted = voted);
  }

  Future<void> _vote() async {
    if (_isVoting || (_hasVoted ?? true)) return;
    setState(() => _isVoting = true);
    try {
      await IniciativasService.instance.vote(widget.iniciativa['id'] as String);
      if (mounted) setState(() => _hasVoted = true);
    } on AlreadyVotedIniciativaException {
      if (mounted) setState(() => _hasVoted = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo registrar tu apoyo. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Future<void> _loadCheckinState() async {
    final checkedIn = await CheckinService.instance.hasCheckedIn(
      widget.iniciativa['id'] as String,
    );
    if (mounted) setState(() => _hasCheckedIn = checkedIn);
  }

  Future<void> _openScanner() async {
    if (_isCheckingIn || (_hasCheckedIn ?? true)) return;
    setState(() => _isCheckingIn = true);
    try {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CheckinScannerScreen(
            iniciativaId: widget.iniciativa['id'] as String,
            iniciativaTitle:
                widget.iniciativa['title'] as String? ?? 'Iniciativa',
          ),
        ),
      );
      if (result == true && mounted) setState(() => _hasCheckedIn = true);
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  static IconData _iconForCategory(String category) {
    switch (category) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: IniciativasService.instance.iniciativasStream(),
        initialData: [widget.iniciativa],
        builder: (context, snapshot) {
          final iniciativa = (snapshot.data ?? [])
              .cast<Map<String, dynamic>>()
              .where((v) => v['id'] == widget.iniciativa['id'])
              .fold<Map<String, dynamic>>(widget.iniciativa, (_, v) => v);

          final category = iniciativa['category'] as String? ?? '';
          final title = iniciativa['title'] as String? ?? 'Iniciativa';
          final description = iniciativa['description'] as String?;
          final location = iniciativa['location'] as String?;
          final organizationName = iniciativa['organization_name'] as String?;
          final organizationId = iniciativa['author_id'] as String?;
          final verificationMethod =
              iniciativa['verification_method'] as String?;
          final votesCount = (iniciativa['votes_count'] as num?)?.toInt() ?? 0;
          final voted = _hasVoted ?? false;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  iniciativaId: iniciativa['id'] as String,
                  statusLabel: 'Iniciativa activa',
                  title: title,
                  category: category,
                  categoryIcon: _iconForCategory(category),
                  votesCount: votesCount,
                  organizationName: organizationName,
                  organizationId: organizationId,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apoyo comunitario',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primarioNegro,
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
                                icon: Icons.thumb_up_alt,
                                iconColor: Colors.white,
                                title: '$votesCount apoyos',
                                titleColor: Colors.white,
                                subtitle: 'Súmate a esta iniciativa',
                                subtitleColor: Colors.white.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                backgroundColor: AppColors.gris200,
                                icon: Icons.location_on,
                                iconColor: AppColors.primarioNegro,
                                title: 'Ubicación',
                                titleColor: AppColors.primarioNegro,
                                subtitle:
                                    (location != null && location.isNotEmpty)
                                    ? location
                                    : 'Sin ubicación registrada',
                                subtitleColor: AppColors.gris700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (verificationMethod != null) ...[
                        const SizedBox(height: 16),
                        _VerificationRow(method: verificationMethod),
                      ],
                      const SizedBox(height: 20),
                      _TabRow(
                        selected: _tab,
                        onSelected: (t) => setState(() => _tab = t),
                      ),
                      const SizedBox(height: 16),
                      _TabContent(tab: _tab, description: description),
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
                                      ? 'Ya apoyaste'
                                      : 'Apoyar esta iniciativa',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      if (category != 'Ahorro') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed:
                                (_hasCheckedIn == null ||
                                    _hasCheckedIn == true ||
                                    _isCheckingIn)
                                ? null
                                : _openScanner,
                            icon: _isCheckingIn
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primarioRojo,
                                    ),
                                  )
                                : const Icon(Icons.qr_code_scanner, size: 20),
                            label: Text(
                              _hasCheckedIn == true
                                  ? 'Ya hiciste check-in'
                                  : 'Escanear QR para check-in',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primarioRojo,
                              side: const BorderSide(
                                color: AppColors.primarioRojo,
                              ),
                              disabledForegroundColor: AppColors.gris600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
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
  final String iniciativaId;
  final String statusLabel;
  final String title;
  final String category;
  final IconData categoryIcon;
  final int votesCount;
  final String? organizationName;
  final String? organizationId;

  const _Header({
    required this.iniciativaId,
    required this.statusLabel,
    required this.title,
    required this.category,
    required this.categoryIcon,
    required this.votesCount,
    this.organizationName,
    this.organizationId,
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
                      SaveButton(itemType: 'iniciativa', itemId: iniciativaId),
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
                            categoryIcon,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (organizationName != null &&
                          organizationName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.apartment,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                organizationName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (organizationId != null) ...[
                              const SizedBox(width: 8),
                              FollowButton(
                                targetUserId: organizationId!,
                                light: true,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Apoyos\nrecibidos',
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
                          Icons.thumb_up_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$votesCount',
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

class _VerificationRow extends StatelessWidget {
  final String method;
  const _VerificationRow({required this.method});

  static const _labels = {
    'qr': 'Código QR para check-in',
    'manual': 'Registro manual',
    'foto': 'Evidencia fotográfica',
  };

  static const _icons = {
    'qr': Icons.qr_code,
    'manual': Icons.edit_note,
    'foto': Icons.photo_camera_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gris200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            _icons[method] ?? Icons.verified_outlined,
            size: 18,
            color: AppColors.primarioNegro,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Método de verificación',
                  style: TextStyle(fontSize: 11, color: AppColors.gris600),
                ),
                Text(
                  _labels[method] ?? method,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primarioNegro,
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
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
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

  const _TabContent({required this.tab, required this.description});

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
      case _DetailTab.presupuesto:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Próximamente',
              style: TextStyle(color: AppColors.gris600),
            ),
          ),
        );
    }
  }
}
