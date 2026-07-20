import 'package:flutter/material.dart';

import '../services/mis_acciones_service.dart';
import '../services/saved_items_service.dart';
import '../theme/app_colors.dart';
import 'iniciativa_detail_screen.dart';
import 'votacion_detail_screen.dart';

enum _MainFilter { participaciones, guardado }

class MisAccionesScreen extends StatefulWidget {
  const MisAccionesScreen({super.key});

  @override
  State<MisAccionesScreen> createState() => _MisAccionesScreenState();
}

class _MisAccionesScreenState extends State<MisAccionesScreen> {
  final _searchController = TextEditingController();

  bool _isLoading = true;
  AccionesStats _stats = AccionesStats.empty;
  List<Map<String, dynamic>> _acciones = [];
  List<Map<String, dynamic>> _guardados = [];

  _MainFilter _mainFilter = _MainFilter.participaciones;
  String _actionTypeFilter = 'todos';

  static const _actionTypeLabels = {
    'todos': 'Todos',
    'apoyo': 'Apoyos',
    'voto': 'Votos',
    'checkin': 'Check-ins',
    'canje': 'Canjes',
  };

  static const _actionTypeIcons = {
    'apoyo': Icons.thumb_up_alt_outlined,
    'voto': Icons.how_to_vote_outlined,
    'checkin': Icons.qr_code_scanner,
    'canje': Icons.local_offer_outlined,
  };

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
      final stats = await MisAccionesService.instance.fetchStats();
      final acciones = await MisAccionesService.instance.fetchAcciones();
      final guardados = await SavedItemsService.instance
          .fetchSavedItemsWithDetails();
      if (mounted) {
        setState(() {
          _stats = stats;
          _acciones = acciones;
          _guardados = guardados;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAcciones {
    final query = _searchController.text.trim().toLowerCase();
    return _acciones.where((a) {
      if (_actionTypeFilter != 'todos' &&
          a['action_type'] != _actionTypeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final title = (a['title'] as String? ?? '').toLowerCase();
      final subtitle = (a['subtitle'] as String? ?? '').toLowerCase();
      return title.contains(query) || subtitle.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredGuardados {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _guardados;
    return _guardados.where((g) {
      final detail = g['detail'] as Map<String, dynamic>;
      final title = (detail['title'] as String? ?? '').toLowerCase();
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
        title: const Text('Tus acciones'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            )
          : RefreshIndicator(
              color: AppColors.primarioRojo,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _StatsRow(stats: _stats),
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
                        hintText: 'Buscar en tus acciones...',
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MainFilterChip(
                          label: 'Participaciones',
                          selected: _mainFilter == _MainFilter.participaciones,
                          onTap: () => setState(
                            () => _mainFilter = _MainFilter.participaciones,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MainFilterChip(
                          label: 'Guardado',
                          selected: _mainFilter == _MainFilter.guardado,
                          onTap: () => setState(
                            () => _mainFilter = _MainFilter.guardado,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_mainFilter == _MainFilter.participaciones) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _actionTypeLabels.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(entry.value),
                              selected: _actionTypeFilter == entry.key,
                              onSelected: (_) =>
                                  setState(() => _actionTypeFilter = entry.key),
                              selectedColor: AppColors.primarioRojo,
                              backgroundColor: AppColors.primarioBlanco,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _actionTypeFilter == entry.key
                                    ? Colors.white
                                    : AppColors.gris700,
                              ),
                              side: BorderSide(
                                color: _actionTypeFilter == entry.key
                                    ? AppColors.primarioRojo
                                    : AppColors.gris300,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_mainFilter == _MainFilter.participaciones)
                    ..._buildAcciones()
                  else
                    ..._buildGuardados(),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildAcciones() {
    final acciones = _filteredAcciones;
    if (acciones.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'No tienes participaciones que coincidan.',
              style: TextStyle(color: AppColors.gris600),
            ),
          ),
        ),
      ];
    }
    return acciones
        .map(
          (accion) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AccionRow(
              accion: accion,
              actionTypeIcons: _actionTypeIcons,
              actionTypeLabels: _actionTypeLabels,
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildGuardados() {
    final guardados = _filteredGuardados;
    if (guardados.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'No tienes nada guardado todavía.',
              style: TextStyle(color: AppColors.gris600),
            ),
          ),
        ),
      ];
    }
    return guardados
        .map(
          (guardado) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GuardadoRow(guardado: guardado, onChanged: _load),
          ),
        )
        .toList();
  }
}

class _StatsRow extends StatelessWidget {
  final AccionesStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.toll,
            value: '${stats.hcBalance}',
            label: 'HeartCoins',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.how_to_vote_outlined,
            value: '${stats.totalVotos}',
            label: 'Votos totales',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.qr_code_scanner,
            value: '${stats.totalCheckins}',
            label: 'Check-ins',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.primarioBlanco,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primarioRojo, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.gris600),
          ),
        ],
      ),
    );
  }
}

class _MainFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MainFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarioRojo : AppColors.primarioBlanco,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primarioRojo : AppColors.gris300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppColors.gris700,
          ),
        ),
      ),
    );
  }
}

class _AccionRow extends StatelessWidget {
  final Map<String, dynamic> accion;
  final Map<String, IconData> actionTypeIcons;
  final Map<String, String> actionTypeLabels;

  const _AccionRow({
    required this.accion,
    required this.actionTypeIcons,
    required this.actionTypeLabels,
  });

  @override
  Widget build(BuildContext context) {
    final actionType = accion['action_type'] as String;
    final title = accion['title'] as String? ?? '';
    final subtitle = accion['subtitle'] as String?;
    final hcDelta = (accion['hc_delta'] as num?)?.toInt() ?? 0;
    final date = DateTime.tryParse(accion['created_at'] as String? ?? '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarioBlanco,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.rojoClaro1.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              actionTypeIcons[actionType] ?? Icons.check_circle_outline,
              color: AppColors.primarioRojo,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primarioNegro,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    actionTypeLabels[actionType] ?? actionType,
                    ?subtitle,
                    if (date != null) '${date.day}/${date.month}/${date.year}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11, color: AppColors.gris600),
                ),
              ],
            ),
          ),
          if (hcDelta != 0)
            Text(
              hcDelta > 0 ? '+$hcDelta HC' : '$hcDelta HC',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: hcDelta > 0
                    ? AppColors.secundarioVerde
                    : AppColors.primarioRojo,
              ),
            ),
        ],
      ),
    );
  }
}

class _GuardadoRow extends StatelessWidget {
  final Map<String, dynamic> guardado;
  final VoidCallback onChanged;

  const _GuardadoRow({required this.guardado, required this.onChanged});

  static const _categoryIcons = {
    'Voluntariado': Icons.groups,
    'Crowdfunding': Icons.volunteer_activism,
    'Social': Icons.diversity_3,
    'Ahorro': Icons.savings,
  };

  @override
  Widget build(BuildContext context) {
    final itemType = guardado['item_type'] as String;
    final detail = guardado['detail'] as Map<String, dynamic>;
    final title = detail['title'] as String? ?? '';
    final subtitle = itemType == 'iniciativa'
        ? detail['organization_name'] as String?
        : detail['foundation_name'] as String?;
    final category = itemType == 'iniciativa'
        ? detail['category'] as String?
        : detail['type'] as String?;

    return Material(
      color: AppColors.primarioBlanco,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (itemType == 'iniciativa') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IniciativaDetailScreen(iniciativa: detail),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VotacionDetailScreen(votacion: detail),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.rojoClaro1.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _categoryIcons[category] ?? Icons.bookmark,
                  color: AppColors.primarioRojo,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primarioNegro,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gris600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.gris400),
            ],
          ),
        ),
      ),
    );
  }
}
