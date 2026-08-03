import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/iniciativa_widgets.dart';

class _TypeOption {
  final String key;
  final String label;
  final IconData icon;
  const _TypeOption(this.key, this.label, this.icon);
}

const _typeOptions = [
  _TypeOption('Voluntariado', 'Voluntariado', Icons.volunteer_activism),
  _TypeOption('Crowdfunding', 'Crowdfunding', Icons.savings_outlined),
  _TypeOption('Social', 'Ac. Social', Icons.favorite),
];

const _impactAreaOptions = [
  'Educación',
  'Salud',
  'Medio ambiente',
  'Derechos humanos',
  'Pobreza',
  'Otro',
];

const _verificationWindowOptions = ['6 hrs', '12 hrs', '24 hrs', '48 hrs'];

const _statusOptions = [
  ('borrador', 'Borrador'),
  ('votacion', 'Votación'),
  ('activa', 'Activa'),
];

class _VerificationMethodOption {
  final String key;
  final String label;
  final IconData icon;
  const _VerificationMethodOption(this.key, this.label, this.icon);
}

const _verificationMethods = [
  _VerificationMethodOption('qr', 'Código QR para check-in', Icons.qr_code),
  _VerificationMethodOption('manual', 'Registro manual', Icons.edit_note),
  _VerificationMethodOption(
    'foto',
    'Evidencia fotográfica',
    Icons.photo_camera_outlined,
  ),
];

const _evidenceOptions = [
  ('asistencia', 'Asistencia', Icons.badge_outlined),
  ('fotografias', 'Fotografías', Icons.image_outlined),
  ('encuesta', 'Encuesta', Icons.quiz_outlined),
  ('testimonio', 'Testimonio', Icons.rate_review_outlined),
];

class EditOrgIniciativaScreen extends StatefulWidget {
  final Map<String, dynamic> iniciativa;
  const EditOrgIniciativaScreen({super.key, required this.iniciativa});

  @override
  State<EditOrgIniciativaScreen> createState() =>
      _EditOrgIniciativaScreenState();
}

class _EditOrgIniciativaScreenState extends State<EditOrgIniciativaScreen> {
  final _client = Supabase.instance.client;
  bool _isSubmitting = false;

  late String _status;
  late String _selectedType;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _impactArea;
  DateTime? _eventDate;

  late List<TextEditingController> _activityControllers;
  late List<TextEditingController> _requirementControllers;
  late List<TextEditingController> _participantProfileControllers;
  late final TextEditingController _maxParticipantsController;

  late String _verificationMethod;
  late Set<String> _requiredEvidence;
  late String _verificationWindow;
  late final TextEditingController _hcRewardController;

  DateTime? _votingEndsAt;

  @override
  void initState() {
    super.initState();
    final i = widget.iniciativa;

    _status = i['status'] as String? ?? 'borrador';
    _selectedType = i['category'] as String? ?? _typeOptions.first.key;
    _titleController = TextEditingController(text: i['title'] as String? ?? '');
    _descriptionController = TextEditingController(
      text: i['description'] as String? ?? '',
    );
    _impactArea = _impactAreaOptions.contains(i['impact_area'])
        ? i['impact_area'] as String
        : _impactAreaOptions.first;
    _eventDate = _parseDate(i['event_date'] as String?);

    _activityControllers = _controllersFrom(i['activities']);
    _requirementControllers = _controllersFrom(i['requirements']);
    _participantProfileControllers = _controllersFrom(i['participant_profile']);
    _maxParticipantsController = TextEditingController(
      text: (i['max_participants'] as num?)?.toString() ?? '',
    );

    _verificationMethod =
        _verificationMethods.any((m) => m.key == i['verification_method'])
        ? i['verification_method'] as String
        : 'qr';
    _requiredEvidence = ((i['required_evidence'] as List?) ?? [])
        .map((e) => e.toString())
        .toSet();
    final windowHours = (i['verification_window_hours'] as num?)?.toInt();
    _verificationWindow = _verificationWindowOptions.firstWhere(
      (o) => o.startsWith('$windowHours '),
      orElse: () => _verificationWindowOptions[1],
    );

    _votingEndsAt = _parseDate(i['voting_ends_at'] as String?);

    _hcRewardController = TextEditingController(
      text: ((i['hc_reward'] as num?)?.toInt() ?? 50).toString(),
    );
  }

  DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  List<TextEditingController> _controllersFrom(dynamic value) {
    final items = ((value as List?) ?? []).map((e) => e.toString()).toList();
    if (items.isEmpty) return [TextEditingController()];
    return items.map((e) => TextEditingController(text: e)).toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _maxParticipantsController.dispose();
    _hcRewardController.dispose();
    for (final c in _activityControllers) {
      c.dispose();
    }
    for (final c in _requirementControllers) {
      c.dispose();
    }
    for (final c in _participantProfileControllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _nonEmpty(List<TextEditingController> controllers) =>
      controllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primarioRojo,
            onPrimary: Colors.white,
            onSurface: AppColors.primarioNegro,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _pickVotingEndsAt() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _votingEndsAt ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primarioRojo,
            onPrimary: Colors.white,
            onSurface: AppColors.primarioNegro,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _votingEndsAt = picked);
  }

  Future<void> _save() async {
    if (_isSubmitting) return;
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa al menos título y descripción.'),
        ),
      );
      return;
    }

    final maxParticipants = int.tryParse(
      _maxParticipantsController.text.trim(),
    );
    final verificationWindowHours =
        int.tryParse(_verificationWindow.split(' ').first) ?? 12;
    final hcReward = int.tryParse(_hcRewardController.text.trim()) ?? 50;

    setState(() => _isSubmitting = true);
    try {
      await _client
          .from('iniciativas')
          .update({
            'status': _status,
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category': _selectedType,
            'impact_area': _impactArea,
            'event_date': _eventDate?.toIso8601String(),
            'activities': _nonEmpty(_activityControllers),
            'requirements': _nonEmpty(_requirementControllers),
            'participant_profile': _nonEmpty(_participantProfileControllers),
            'max_participants': maxParticipants,
            'votes_goal': maxParticipants,
            'voting_ends_at': _votingEndsAt?.toIso8601String(),
            'verification_method': _verificationMethod,
            'required_evidence': _requiredEvidence.toList(),
            'verification_window_hours': verificationWindowHours,
            'hc_reward': hcReward,
          })
          .eq('id', widget.iniciativa['id'] as String);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar. Intenta de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
        title: const Text('Editar iniciativa'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _FieldLabel('Estado'),
          Row(
            children: _statusOptions.map((option) {
              final (key, label) = option;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppChip(
                    label: label,
                    selected: _status == key,
                    onTap: () => setState(() => _status = key),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          Row(
            children: _typeOptions.map((option) {
              final isSelected = option.key == _selectedType;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = option.key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primarioRojo
                          : AppColors.primarioBlanco,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          option.icon,
                          color: isSelected ? Colors.white : AppColors.gris600,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : AppColors.gris700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          _FieldLabel('Título *'),
          _TextInput(
            controller: _titleController,
            hint: 'Título de la iniciativa',
          ),
          const SizedBox(height: 16),

          _FieldLabel('Descripción *'),
          _TextInput(
            controller: _descriptionController,
            hint: 'Describe la iniciativa',
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          _FieldLabel('Categoría'),
          _Dropdown(
            value: _impactArea,
            options: _impactAreaOptions,
            onChanged: (v) => setState(() => _impactArea = v),
          ),
          const SizedBox(height: 16),

          _FieldLabel('Fecha del evento'),
          _DateField(date: _eventDate, onTap: _pickEventDate),
          const SizedBox(height: 24),

          _DynamicList(
            label: 'Actividades a realizar',
            controllers: _activityControllers,
            onAdd: () => setState(
              () => _activityControllers.add(TextEditingController()),
            ),
          ),
          const SizedBox(height: 20),
          _DynamicList(
            label: 'Requisitos para participantes',
            controllers: _requirementControllers,
            onAdd: () => setState(
              () => _requirementControllers.add(TextEditingController()),
            ),
          ),
          const SizedBox(height: 20),
          _DynamicList(
            label: 'Perfil del participante',
            controllers: _participantProfileControllers,
            onAdd: () => setState(
              () => _participantProfileControllers.add(TextEditingController()),
            ),
          ),
          const SizedBox(height: 20),

          _FieldLabel('Cantidad de Participantes'),
          _TextInput(
            controller: _maxParticipantsController,
            hint: 'Ej. 50',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),

          _FieldLabel('Método de verificación'),
          for (final method in _verificationMethods) ...[
            GestureDetector(
              onTap: () => setState(() => _verificationMethod = method.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _verificationMethod == method.key
                      ? AppColors.primarioRojo
                      : AppColors.primarioBlanco,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      _verificationMethod == method.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _verificationMethod == method.key
                          ? Colors.white
                          : AppColors.gris400,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        method.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _verificationMethod == method.key
                              ? Colors.white
                              : AppColors.primarioNegro,
                        ),
                      ),
                    ),
                    Icon(
                      method.icon,
                      color: _verificationMethod == method.key
                          ? Colors.white
                          : AppColors.gris600,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),

          _FieldLabel('Evidencia requerida'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: _evidenceOptions.map((option) {
              final (key, label, icon) = option;
              final isSelected = _requiredEvidence.contains(key);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _requiredEvidence.remove(key);
                  } else {
                    _requiredEvidence.add(key);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarioBlanco,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primarioRojo
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: AppColors.primarioNegro, size: 20),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primarioNegro,
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                          color: isSelected
                              ? AppColors.primarioRojo
                              : AppColors.gris400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          _FieldLabel('Tiempo de verificación'),
          _Dropdown(
            value: _verificationWindow,
            options: _verificationWindowOptions,
            onChanged: (v) => setState(() => _verificationWindow = v),
          ),
          const SizedBox(height: 20),

          _FieldLabel('Recompensa en HC por check-in'),
          _TextInput(
            controller: _hcRewardController,
            hint: 'Ej. 50',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),

          _FieldLabel('Fecha límite de votación'),
          _DateField(date: _votingEndsAt, onTap: _pickVotingEndsAt),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarioRojo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Guardar cambios',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primarioNegro,
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _TextInput({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 14, color: AppColors.primarioNegro),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.gris400),
        filled: true,
        fillColor: AppColors.primarioBlanco,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gris300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gris300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primarioRojo,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _Dropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.primarioBlanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gris300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.gris600),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primarioBlanco,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gris300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null
                    ? '${date!.day}/${date!.month}/${date!.year}'
                    : 'Selecciona una fecha',
                style: TextStyle(
                  fontSize: 14,
                  color: date != null
                      ? AppColors.primarioNegro
                      : AppColors.gris600,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: AppColors.gris600),
          ],
        ),
      ),
    );
  }
}

class _DynamicList extends StatelessWidget {
  final String label;
  final List<TextEditingController> controllers;
  final VoidCallback onAdd;

  const _DynamicList({
    required this.label,
    required this.controllers,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        for (final controller in controllers) ...[
          _TextInput(controller: controller, hint: 'Lorem Ipsum Dolor'),
          const SizedBox(height: 10),
        ],
        GestureDetector(
          onTap: onAdd,
          child: const Row(
            children: [
              Icon(Icons.add, size: 16, color: AppColors.primarioRojo),
              SizedBox(width: 4),
              Text(
                'Agregar otro',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarioRojo,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
