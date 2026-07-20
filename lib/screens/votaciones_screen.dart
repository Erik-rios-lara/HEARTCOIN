import 'package:flutter/material.dart';

import '../services/votaciones_service.dart';
import '../theme/app_colors.dart';
import '../widgets/save_button.dart';
import 'votacion_detail_screen.dart';

enum _VotacionesFilter { todas, porTiempo, masHc }

class VotacionesScreen extends StatefulWidget {
  const VotacionesScreen({super.key});

  @override
  State<VotacionesScreen> createState() => _VotacionesScreenState();
}

class _VotacionesScreenState extends State<VotacionesScreen> {
  final _searchController = TextEditingController();
  _VotacionesFilter _filter = _VotacionesFilter.todas;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterAndSort(List<Map<String, dynamic>> source) {
    final search = _searchController.text.trim().toLowerCase();
    var list = source.where((v) {
      if (search.isEmpty) return true;
      final title = (v['title'] as String? ?? '').toLowerCase();
      final foundation = (v['foundation_name'] as String? ?? '').toLowerCase();
      return title.contains(search) || foundation.contains(search);
    }).toList();

    switch (_filter) {
      case _VotacionesFilter.todas:
        list.sort(
          (a, b) => (b['created_at'] as String? ?? '').compareTo(
            a['created_at'] as String? ?? '',
          ),
        );
        break;
      case _VotacionesFilter.porTiempo:
        list.sort((a, b) {
          final endsA = a['ends_at'] as String?;
          final endsB = b['ends_at'] as String?;
          if (endsA == null && endsB == null) return 0;
          if (endsA == null) return 1;
          if (endsB == null) return -1;
          return endsA.compareTo(endsB);
        });
        break;
      case _VotacionesFilter.masHc:
        list.sort(
          (a, b) => ((b['hc_reward'] as num?) ?? 0).compareTo(
            (a['hc_reward'] as num?) ?? 0,
          ),
        );
        break;
    }
    return list;
  }

  void _openFiltersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primarioBlanco,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ordenar por',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              _FilterChips(
                selected: _filter,
                onSelected: (f) {
                  Navigator.of(sheetContext).pop();
                  setState(() => _filter = f);
                },
              ),
              SizedBox(height: MediaQuery.of(sheetContext).padding.bottom + 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioBlanco,
        foregroundColor: AppColors.primarioNegro,
        elevation: 0,
        title: const Text('Iniciativas por votar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primarioBlanco,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.gris300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar iniciativas o fundaciones...',
                        hintStyle: TextStyle(color: AppColors.gris600),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.gris600,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primarioRojo,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    onPressed: _openFiltersSheet,
                    icon: const Icon(Icons.tune, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 36,
              child: _FilterChips(
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
                scrollable: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: VotacionesService.instance.votacionesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primarioRojo,
                    ),
                  );
                }

                final votaciones = _filterAndSort(snapshot.data ?? []);
                if (votaciones.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay iniciativas que coincidan.',
                      style: TextStyle(color: AppColors.gris600),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: votaciones.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _VotacionCard(votacion: votaciones[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final _VotacionesFilter selected;
  final ValueChanged<_VotacionesFilter> onSelected;
  final bool scrollable;

  const _FilterChips({
    required this.selected,
    required this.onSelected,
    this.scrollable = false,
  });

  static const _labels = {
    _VotacionesFilter.todas: 'Todas',
    _VotacionesFilter.porTiempo: 'Por tiempo',
    _VotacionesFilter.masHc: '+HC',
  };

  @override
  Widget build(BuildContext context) {
    final chips = _VotacionesFilter.values
        .map(
          (option) => _Chip(
            label: _labels[option]!,
            selected: selected == option,
            onTap: () => onSelected(option),
          ),
        )
        .toList();

    if (!scrollable) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: chips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) => chips[index],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarioRojo : AppColors.primarioBlanco,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primarioRojo : AppColors.gris300,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.gris700,
          ),
        ),
      ),
    );
  }
}

class _VotacionCard extends StatefulWidget {
  final Map<String, dynamic> votacion;
  const _VotacionCard({required this.votacion});

  @override
  State<_VotacionCard> createState() => _VotacionCardState();
}

class _VotacionCardState extends State<_VotacionCard> {
  bool? _hasVoted;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _loadVoteState();
  }

  @override
  void didUpdateWidget(covariant _VotacionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.votacion['id'] != widget.votacion['id']) _loadVoteState();
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

  @override
  Widget build(BuildContext context) {
    final votacion = widget.votacion;
    final type = votacion['type'] as String? ?? '';
    final title = votacion['title'] as String? ?? 'Iniciativa';
    final foundation = votacion['foundation_name'] as String? ?? '';
    final impactArea = votacion['impact_area'] as String?;
    final hcReward = (votacion['hc_reward'] as num?)?.toInt() ?? 0;
    final votesCount = (votacion['votes_count'] as num?)?.toInt() ?? 0;
    final votesGoal = (votacion['votes_goal'] as num?)?.toInt() ?? 1;
    final progress = votesGoal > 0
        ? (votesCount / votesGoal).clamp(0.0, 1.0)
        : 0.0;
    final voted = _hasVoted ?? false;

    return Material(
      color: AppColors.primarioBlanco,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VotacionDetailScreen(votacion: votacion),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.rojoClaro1.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      type,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primarioRojo,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.toll,
                    size: 16,
                    color: AppColors.secundarioAmarillo,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$hcReward HC',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarioNegro,
                    ),
                  ),
                  if (votacion['id'] != null) ...[
                    const SizedBox(width: 8),
                    SaveButton(
                      itemType: 'votacion',
                      itemId: votacion['id'] as String,
                      color: AppColors.primarioRojo,
                      compact: true,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
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
                foundation,
                style: TextStyle(fontSize: 13, color: AppColors.gris700),
              ),
              if (impactArea != null && impactArea.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.public, size: 14, color: AppColors.gris600),
                    const SizedBox(width: 4),
                    Text(
                      impactArea,
                      style: TextStyle(fontSize: 12, color: AppColors.gris600),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.gris200,
                  color: AppColors.primarioRojo,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$votesCount de $votesGoal votos',
                style: TextStyle(fontSize: 12, color: AppColors.gris600),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: (_hasVoted == null || voted || _isVoting)
                      ? null
                      : _vote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: voted
                        ? AppColors.gris300
                        : AppColors.primarioRojo,
                    foregroundColor: voted ? AppColors.gris700 : Colors.white,
                    disabledBackgroundColor: AppColors.gris300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isVoting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(voted ? 'Ya votaste' : 'Votar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
