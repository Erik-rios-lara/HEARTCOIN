import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/iniciativa_participants_service.dart';
import '../services/iniciativas_service.dart';
import '../theme/app_colors.dart';
import 'invite_participant_screen.dart';

enum _AhorroTab { general, proveedor, actividad }

/// Cuerpo del detalle para iniciativas de categoría "Ahorro": progreso,
/// participantes reales (Titular/Participante), invitar, solicitar
/// unirme, y proveedor asociado. "Avances reportados", "Contrato" y el
/// tab "Actividad" quedan como "Próximamente": no hay panel de proveedor
/// en esta app que los alimente todavía.
class IniciativaAhorroDetailBody extends StatefulWidget {
  final Map<String, dynamic> iniciativa;

  const IniciativaAhorroDetailBody({super.key, required this.iniciativa});

  @override
  State<IniciativaAhorroDetailBody> createState() =>
      _IniciativaAhorroDetailBodyState();
}

class _IniciativaAhorroDetailBodyState
    extends State<IniciativaAhorroDetailBody> {
  final _service = IniciativaParticipantsService.instance;
  final _myId = Supabase.instance.client.auth.currentUser?.id;

  _AhorroTab _tab = _AhorroTab.general;

  bool _isLoading = true;
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  String? _myRequestStatus;
  Map<String, dynamic>? _provider;

  String get _iniciativaId => widget.iniciativa['id'] as String;
  String? get _authorId => widget.iniciativa['author_id'] as String?;
  bool get _isOwner => _myId != null && _myId == _authorId;
  bool get _isParticipant =>
      !_isOwner &&
      _participants.any((p) => p['user_id'] == _myId && p['role'] == 'participante');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant IniciativaAhorroDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iniciativa['provider_id'] != widget.iniciativa['provider_id']) {
      _loadProvider();
    }
  }

  Future<void> _load() async {
    await Future.wait([_loadParticipants(), _loadProvider()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadParticipants() async {
    try {
      final participants = await _service.fetchParticipants(_iniciativaId);
      if (!mounted) return;
      setState(() => _participants = participants);

      if (_isOwner) {
        final pending = await _service.fetchPendingRequests(_iniciativaId);
        if (mounted) setState(() => _pendingRequests = pending);
      } else if (!_isParticipant) {
        final status = await _service.myRequestStatus(_iniciativaId);
        if (mounted) setState(() => _myRequestStatus = status);
      }
    } catch (_) {
      // Si falla, simplemente se muestra la lista vacía.
    }
  }

  Future<void> _loadProvider() async {
    final providerId = widget.iniciativa['provider_id'] as String?;
    if (providerId == null) {
      if (mounted) setState(() => _provider = null);
      return;
    }
    try {
      final provider = await Supabase.instance.client
          .from('proveedores')
          .select()
          .eq('id', providerId)
          .maybeSingle();
      if (mounted) setState(() => _provider = provider);
    } catch (_) {
      // Sin proveedor cargado, la pestaña simplemente muestra lo básico.
    }
  }

  Future<void> _inviteParticipant() async {
    final excluded = _participants.map((p) => p['user_id'] as String).toSet();
    final invited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InviteParticipantScreen(
          iniciativaId: _iniciativaId,
          excludedUserIds: excluded,
        ),
      ),
    );
    if (invited == true) _loadParticipants();
  }

  Future<void> _requestToJoin() async {
    try {
      await _service.requestToJoin(_iniciativaId);
      if (mounted) setState(() => _myRequestStatus = 'pending');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar tu solicitud. Intenta de nuevo.'),
          ),
        );
      }
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      await _service.acceptRequest(requestId);
      _loadParticipants();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo aceptar la solicitud.')),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await _service.rejectRequest(requestId);
      _loadParticipants();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo rechazar la solicitud.')),
        );
      }
    }
  }

  Future<void> _editCurrentAmount() async {
    final targetAmount = (widget.iniciativa['target_amount'] as num?)
            ?.toDouble() ??
        0;
    final currentAmount = (widget.iniciativa['current_amount'] as num?)
            ?.toDouble() ??
        0;
    final controller = TextEditingController(
      text: currentAmount == currentAmount.roundToDouble()
          ? currentAmount.toStringAsFixed(0)
          : currentAmount.toString(),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Actualizar progreso'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '\$ ',
            hintText: 'Meta: \$${targetAmount.toStringAsFixed(0)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(
                controller.text.trim().replaceAll(',', ''),
              );
              Navigator.of(dialogContext).pop(value);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.primarioRojo),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await IniciativasService.instance.updateCurrentAmount(
        _iniciativaId,
        result,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el progreso.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primarioRojo),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressCard(
            iniciativa: widget.iniciativa,
            canEdit: _isOwner,
            onEdit: _editCurrentAmount,
          ),
          const SizedBox(height: 20),
          _AhorroTabRow(selected: _tab, onSelected: (t) => setState(() => _tab = t)),
          const SizedBox(height: 16),
          switch (_tab) {
            _AhorroTab.general => _GeneralTab(
              iniciativa: widget.iniciativa,
              isOwner: _isOwner,
              isParticipant: _isParticipant,
              participants: _participants,
              pendingRequests: _pendingRequests,
              myRequestStatus: _myRequestStatus,
              onInvite: _inviteParticipant,
              onRequestToJoin: _requestToJoin,
              onAcceptRequest: _acceptRequest,
              onRejectRequest: _rejectRequest,
            ),
            _AhorroTab.proveedor => _ProveedorTab(provider: _provider),
            _AhorroTab.actividad => const _ComingSoon(
              message: 'La actividad de esta iniciativa estará disponible pronto.',
            ),
          },
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final Map<String, dynamic> iniciativa;
  final bool canEdit;
  final VoidCallback onEdit;

  const _ProgressCard({
    required this.iniciativa,
    required this.canEdit,
    required this.onEdit,
  });

  static const _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  String _formatDate(DateTime date) =>
      '${date.day} de ${_months[date.month - 1]} de ${date.year}';

  @override
  Widget build(BuildContext context) {
    final targetAmount = (iniciativa['target_amount'] as num?)?.toDouble() ?? 0;
    final currentAmount = (iniciativa['current_amount'] as num?)?.toDouble() ?? 0;
    final progress = targetAmount > 0
        ? (currentAmount / targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final targetDate = DateTime.tryParse(
      iniciativa['target_date'] as String? ?? '',
    );

    return GestureDetector(
      onTap: canEdit ? onEdit : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primarioBlanco,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gris200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progreso actual: \$${currentAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primarioNegro,
                  ),
                ),
                if (canEdit) Icon(Icons.edit, size: 16, color: AppColors.gris600),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.gris200,
                color: AppColors.primarioRojo,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: AppColors.gris600),
                ),
                Text(
                  'Meta \$${targetAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gris600,
                  ),
                ),
              ],
            ),
            if (targetDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Fecha objetivo: ${_formatDate(targetDate)}',
                style: TextStyle(fontSize: 12, color: AppColors.gris600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AhorroTabRow extends StatelessWidget {
  final _AhorroTab selected;
  final ValueChanged<_AhorroTab> onSelected;

  const _AhorroTabRow({required this.selected, required this.onSelected});

  static const _labels = {
    _AhorroTab.general: 'General',
    _AhorroTab.proveedor: 'Proveedor',
    _AhorroTab.actividad: 'Actividad',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _AhorroTab.values.map((tab) {
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

class _GeneralTab extends StatelessWidget {
  final Map<String, dynamic> iniciativa;
  final bool isOwner;
  final bool isParticipant;
  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> pendingRequests;
  final String? myRequestStatus;
  final VoidCallback onInvite;
  final VoidCallback onRequestToJoin;
  final ValueChanged<String> onAcceptRequest;
  final ValueChanged<String> onRejectRequest;

  const _GeneralTab({
    required this.iniciativa,
    required this.isOwner,
    required this.isParticipant,
    required this.participants,
    required this.pendingRequests,
    required this.myRequestStatus,
    required this.onInvite,
    required this.onRequestToJoin,
    required this.onAcceptRequest,
    required this.onRejectRequest,
  });

  @override
  Widget build(BuildContext context) {
    final authorName = participants.isNotEmpty
        ? participants.first['full_name'] as String? ?? 'el titular'
        : 'el titular';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isParticipant) ...[
          _JoinedBanner(authorName: authorName),
          const SizedBox(height: 20),
        ],
        if (isOwner || isParticipant) ...[
          Text(
            'Participantes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 12),
          _ParticipantsList(participants: participants),
          if (isOwner) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onInvite,
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Invitar participante'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primarioRojo,
                side: const BorderSide(color: AppColors.primarioRojo),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          if (isOwner && pendingRequests.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Solicitudes pendientes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primarioNegro,
              ),
            ),
            const SizedBox(height: 12),
            ...pendingRequests.map(
              (request) => _PendingRequestTile(
                request: request,
                onAccept: () => onAcceptRequest(request['id'] as String),
                onReject: () => onRejectRequest(request['id'] as String),
              ),
            ),
          ],
        ] else ...[
          Text(
            'Descripción',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (iniciativa['description'] as String?)?.isNotEmpty == true
                ? iniciativa['description'] as String
                : 'Esta iniciativa aún no tiene una descripción detallada.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.gris800),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Actividad reciente',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primarioNegro,
          ),
        ),
        const SizedBox(height: 8),
        const _ComingSoon(message: 'Próximamente'),
        if (!isOwner && !isParticipant) ...[
          const SizedBox(height: 20),
          _RequestToJoinCard(
            status: myRequestStatus,
            onRequestToJoin: onRequestToJoin,
          ),
        ],
      ],
    );
  }
}

class _JoinedBanner extends StatelessWidget {
  final String authorName;
  const _JoinedBanner({required this.authorName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secundarioAzul.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.secundarioAzul.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.secundarioAzul, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '¡Estás participando en esta iniciativa! $authorName te invitó a ser '
              'parte de esta iniciativa y podrás ver detalle de sus avances.',
              style: TextStyle(fontSize: 13, color: AppColors.primarioNegro, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantsList extends StatelessWidget {
  final List<Map<String, dynamic>> participants;
  const _ParticipantsList({required this.participants});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: participants.map((participant) {
        final isTitular = participant['role'] == 'titular';
        final avatarUrl = participant['avatar_url'] as String?;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.gris200,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Icon(Icons.person, color: AppColors.gris600, size: 18)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  participant['full_name'] as String? ?? 'Usuario',
                  style: TextStyle(fontSize: 14, color: AppColors.primarioNegro),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isTitular
                      ? AppColors.rojoClaro1.withValues(alpha: 0.2)
                      : AppColors.secundarioAzul.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isTitular ? 'Titular' : 'Participante',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isTitular ? AppColors.primarioRojo : AppColors.secundarioAzul,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PendingRequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingRequestTile({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = request['avatar_url'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.gris200,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(Icons.person, color: AppColors.gris600, size: 18)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              request['full_name'] as String? ?? 'Usuario',
              style: TextStyle(fontSize: 14, color: AppColors.primarioNegro),
            ),
          ),
          IconButton(
            onPressed: onAccept,
            icon: const Icon(Icons.check_circle, color: AppColors.secundarioVerde),
          ),
          IconButton(
            onPressed: onReject,
            icon: const Icon(Icons.cancel, color: AppColors.primarioRojo),
          ),
        ],
      ),
    );
  }
}

class _RequestToJoinCard extends StatelessWidget {
  final String? status;
  final VoidCallback onRequestToJoin;

  const _RequestToJoinCard({required this.status, required this.onRequestToJoin});

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gris100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Quieres conocer y saber más sobre esta iniciativa?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Puedes solicitar unirte como participante para tener más detalles '
            'y verificar avances.',
            style: TextStyle(fontSize: 12, color: AppColors.gris600),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: isPending ? null : onRequestToJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarioRojo,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.gris300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isPending ? 'Solicitud enviada' : 'Solicita unirme',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProveedorTab extends StatelessWidget {
  final Map<String, dynamic>? provider;
  const _ProveedorTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider == null) {
      return const _ComingSoon(
        message: 'Esta iniciativa aún no tiene un proveedor asociado.',
      );
    }

    final rating = double.tryParse(provider!['rating']?.toString() ?? '') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primarioBlanco,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gris200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      provider!['name'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primarioNegro,
                      ),
                    ),
                  ),
                  ...List.generate(
                    5,
                    (i) => Icon(
                      i < rating.round() ? Icons.star : Icons.star_border,
                      size: 16,
                      color: AppColors.secundarioAmarillo,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(rating.toStringAsFixed(1), style: TextStyle(color: AppColors.gris600)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                provider!['description'] as String? ?? '',
                style: TextStyle(fontSize: 13, color: AppColors.gris700, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Avances reportados',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primarioNegro,
          ),
        ),
        const SizedBox(height: 8),
        const _ComingSoon(message: 'Próximamente'),
        const SizedBox(height: 20),
        Text(
          'Contrato',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primarioNegro,
          ),
        ),
        const SizedBox(height: 8),
        const _ComingSoon(message: 'Próximamente'),
      ],
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String message;
  const _ComingSoon({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.gris100,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.gris600, fontSize: 13),
      ),
    );
  }
}
