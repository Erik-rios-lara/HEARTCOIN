import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

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
const _votingDurationOptions = ['12 hrs', '24 hrs', '3 días', '7 días'];

Duration _parseDurationLabel(String label) {
  final parts = label.split(' ');
  final value = int.tryParse(parts[0]) ?? 12;
  if (label.contains('día')) return Duration(days: value);
  return Duration(hours: value);
}

class CreateOrgIniciativaScreen extends StatefulWidget {
  const CreateOrgIniciativaScreen({super.key});

  @override
  State<CreateOrgIniciativaScreen> createState() =>
      _CreateOrgIniciativaScreenState();
}

class _CreateOrgIniciativaScreenState extends State<CreateOrgIniciativaScreen> {
  final _client = Supabase.instance.client;

  int _step = 0;
  bool _isSubmitting = false;

  // Paso 1
  String _selectedType = _typeOptions.first.key;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _impactArea = _impactAreaOptions.first;
  DateTime? _eventDate;

  // Paso 2
  final List<TextEditingController> _activityControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> _requirementControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> _participantProfileControllers = [
    TextEditingController(),
  ];
  final _maxParticipantsController = TextEditingController();

  // Paso 3
  String _verificationMethod = 'qr';
  final Set<String> _requiredEvidence = {};
  String _verificationWindow = _verificationWindowOptions[1];
  final _hcRewardController = TextEditingController(text: '50');

  // Paso 4
  String _votingDuration = _votingDurationOptions[0];

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

  void _goToStep(int step) => setState(() => _step = step);

  void _onBackPressed() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
    } else {
      _goToStep(_step - 1);
    }
  }

  bool get _canContinueStep1 =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      _eventDate != null;

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
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

  List<String> _nonEmpty(List<TextEditingController> controllers) =>
      controllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final maxParticipants = int.tryParse(
      _maxParticipantsController.text.trim(),
    );
    final verificationWindowHours =
        int.tryParse(_verificationWindow.split(' ').first) ?? 12;
    final hcReward = int.tryParse(_hcRewardController.text.trim()) ?? 50;
    final votingEndsAt = DateTime.now()
        .add(_parseDurationLabel(_votingDuration))
        .toIso8601String();

    setState(() => _isSubmitting = true);
    try {
      await _client.from('iniciativas').insert({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedType,
        'impact_area': _impactArea,
        'author_id': userId,
        'status': 'votacion',
        'event_date': _eventDate?.toIso8601String(),
        'activities': _nonEmpty(_activityControllers),
        'requirements': _nonEmpty(_requirementControllers),
        'participant_profile': _nonEmpty(_participantProfileControllers),
        'max_participants': maxParticipants,
        'votes_goal': maxParticipants,
        'voting_ends_at': votingEndsAt,
        'verification_method': _verificationMethod,
        'required_evidence': _requiredEvidence.toList(),
        'verification_window_hours': verificationWindowHours,
        'hc_reward': hcReward,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo crear la iniciativa. Intenta de nuevo.'),
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
      backgroundColor: AppColors.primarioBlanco,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _onBackPressed,
                    child: Icon(
                      Icons.arrow_back,
                      color: AppColors.primarioNegro,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Crear nueva Iniciativa',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primarioNegro,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Icon(Icons.close, color: AppColors.primarioNegro),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: _StepperHeader(currentStep: _step, totalSteps: 4),
            ),
            Expanded(
              child: switch (_step) {
                0 => _StepDetails(
                  selectedType: _selectedType,
                  onTypeSelected: (t) => setState(() => _selectedType = t),
                  titleController: _titleController,
                  descriptionController: _descriptionController,
                  impactArea: _impactArea,
                  onImpactAreaChanged: (v) => setState(() => _impactArea = v),
                  eventDate: _eventDate,
                  onPickDate: _pickEventDate,
                  canContinue: _canContinueStep1,
                  onContinue: () => _goToStep(1),
                ),
                1 => _StepActivities(
                  activityControllers: _activityControllers,
                  requirementControllers: _requirementControllers,
                  participantProfileControllers: _participantProfileControllers,
                  maxParticipantsController: _maxParticipantsController,
                  onAddActivity: () => setState(
                    () => _activityControllers.add(TextEditingController()),
                  ),
                  onAddRequirement: () => setState(
                    () => _requirementControllers.add(TextEditingController()),
                  ),
                  onAddParticipantProfile: () => setState(
                    () => _participantProfileControllers.add(
                      TextEditingController(),
                    ),
                  ),
                  onContinue: () => _goToStep(2),
                ),
                2 => _StepVerification(
                  verificationMethod: _verificationMethod,
                  onMethodSelected: (m) =>
                      setState(() => _verificationMethod = m),
                  requiredEvidence: _requiredEvidence,
                  onEvidenceToggled: (key) => setState(() {
                    if (_requiredEvidence.contains(key)) {
                      _requiredEvidence.remove(key);
                    } else {
                      _requiredEvidence.add(key);
                    }
                  }),
                  verificationWindow: _verificationWindow,
                  onWindowChanged: (v) =>
                      setState(() => _verificationWindow = v),
                  hcRewardController: _hcRewardController,
                  onContinue: () => _goToStep(3),
                ),
                _ => _StepPreview(
                  type: _typeOptions
                      .firstWhere((t) => t.key == _selectedType)
                      .label,
                  title: _titleController.text.trim(),
                  eventDate: _eventDate,
                  votingDuration: _votingDuration,
                  onVotingDurationChanged: (v) =>
                      setState(() => _votingDuration = v),
                  isSubmitting: _isSubmitting,
                  onSubmit: _submit,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const _StepperHeader({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isEven) {
          final step = i ~/ 2;
          final isDone = step < currentStep;
          final isActive = step == currentStep;
          return Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isDone || isActive)
                  ? AppColors.primarioRojo
                  : AppColors.primarioBlanco,
              border: Border.all(
                color: (isDone || isActive)
                    ? AppColors.primarioRojo
                    : AppColors.gris300,
                width: 2,
              ),
            ),
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 15)
                : isActive
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          );
        }
        final lineDone = (i ~/ 2) < currentStep;
        return Expanded(
          child: Container(
            height: 2,
            color: lineDone ? AppColors.primarioRojo : AppColors.gris300,
          ),
        );
      }),
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

class _ContinueButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _ContinueButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primarioRojo,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.gris300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Continuar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// ============================================================
/// PASO 1: Tipo, título, descripción, categoría, fecha
/// ============================================================
class _StepDetails extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeSelected;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final String impactArea;
  final ValueChanged<String> onImpactAreaChanged;
  final DateTime? eventDate;
  final VoidCallback onPickDate;
  final bool canContinue;
  final VoidCallback onContinue;

  const _StepDetails({
    required this.selectedType,
    required this.onTypeSelected,
    required this.titleController,
    required this.descriptionController,
    required this.impactArea,
    required this.onImpactAreaChanged,
    required this.eventDate,
    required this.onPickDate,
    required this.canContinue,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: _typeOptions.map((option) {
            final isSelected = option.key == selectedType;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTypeSelected(option.key),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primarioRojo
                        : AppColors.gris100,
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
                          color: isSelected ? Colors.white : AppColors.gris700,
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
        _TextInput(controller: titleController, hint: 'Placeholder'),
        const SizedBox(height: 16),

        _FieldLabel('Descripción *'),
        _TextInput(
          controller: descriptionController,
          hint: 'Placeholder',
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        _FieldLabel('Categoría'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.primarioBlanco,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gris300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: impactArea,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: AppColors.gris600),
              items: _impactAreaOptions
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onImpactAreaChanged(v);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        _FieldLabel('Fecha'),
        GestureDetector(
          onTap: onPickDate,
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
                    eventDate != null
                        ? '${eventDate!.day}/${eventDate!.month}/${eventDate!.year}'
                        : 'Selecciona una fecha',
                    style: TextStyle(
                      fontSize: 14,
                      color: eventDate != null
                          ? AppColors.primarioNegro
                          : AppColors.gris600,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: AppColors.gris600),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        _ContinueButton(enabled: canContinue, onPressed: onContinue),
      ],
    );
  }
}

/// ============================================================
/// PASO 2: Actividades, requisitos, perfil, cantidad
/// ============================================================
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

class _StepActivities extends StatelessWidget {
  final List<TextEditingController> activityControllers;
  final List<TextEditingController> requirementControllers;
  final List<TextEditingController> participantProfileControllers;
  final TextEditingController maxParticipantsController;
  final VoidCallback onAddActivity;
  final VoidCallback onAddRequirement;
  final VoidCallback onAddParticipantProfile;
  final VoidCallback onContinue;

  const _StepActivities({
    required this.activityControllers,
    required this.requirementControllers,
    required this.participantProfileControllers,
    required this.maxParticipantsController,
    required this.onAddActivity,
    required this.onAddRequirement,
    required this.onAddParticipantProfile,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _DynamicList(
          label: 'Actividades a realizar',
          controllers: activityControllers,
          onAdd: onAddActivity,
        ),
        const SizedBox(height: 20),
        _DynamicList(
          label: 'Requisitos para participantes',
          controllers: requirementControllers,
          onAdd: onAddRequirement,
        ),
        const SizedBox(height: 20),
        _DynamicList(
          label: 'Perfil del participante',
          controllers: participantProfileControllers,
          onAdd: onAddParticipantProfile,
        ),
        const SizedBox(height: 20),
        _FieldLabel('Cantidad de Participantes'),
        _TextInput(
          controller: maxParticipantsController,
          hint: 'Ej. 50',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 28),
        _ContinueButton(enabled: true, onPressed: onContinue),
      ],
    );
  }
}

/// ============================================================
/// PASO 3: Método de verificación
/// ============================================================
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

class _StepVerification extends StatelessWidget {
  final String verificationMethod;
  final ValueChanged<String> onMethodSelected;
  final Set<String> requiredEvidence;
  final ValueChanged<String> onEvidenceToggled;
  final String verificationWindow;
  final ValueChanged<String> onWindowChanged;
  final TextEditingController hcRewardController;
  final VoidCallback onContinue;

  const _StepVerification({
    required this.verificationMethod,
    required this.onMethodSelected,
    required this.requiredEvidence,
    required this.onEvidenceToggled,
    required this.verificationWindow,
    required this.onWindowChanged,
    required this.hcRewardController,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _FieldLabel('Método de verificación'),
        for (final method in _verificationMethods) ...[
          GestureDetector(
            onTap: () => onMethodSelected(method.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: verificationMethod == method.key
                    ? AppColors.primarioRojo
                    : AppColors.gris100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    verificationMethod == method.key
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: verificationMethod == method.key
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
                        color: verificationMethod == method.key
                            ? Colors.white
                            : AppColors.primarioNegro,
                      ),
                    ),
                  ),
                  Icon(
                    method.icon,
                    color: verificationMethod == method.key
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
            final isSelected = requiredEvidence.contains(key);
            return GestureDetector(
              onTap: () => onEvidenceToggled(key),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gris100,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.primarioBlanco,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gris300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: verificationWindow,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: AppColors.gris600),
              items: _verificationWindowOptions
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onWindowChanged(v);
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        _FieldLabel('Recompensa en HC por check-in'),
        TextField(
          controller: hcRewardController,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: 14, color: AppColors.primarioNegro),
          decoration: InputDecoration(
            hintText: 'Ej. 50',
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
        ),
        const SizedBox(height: 4),
        Text(
          'HC que gana cada participante al confirmar su check-in.',
          style: TextStyle(fontSize: 11, color: AppColors.gris600),
        ),
        const SizedBox(height: 28),

        _ContinueButton(enabled: true, onPressed: onContinue),
      ],
    );
  }
}

/// ============================================================
/// PASO 4: Previsualización + duración de votación
/// ============================================================
class _StepPreview extends StatelessWidget {
  final String type;
  final String title;
  final DateTime? eventDate;
  final String votingDuration;
  final ValueChanged<String> onVotingDurationChanged;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _StepPreview({
    required this.type,
    required this.title,
    required this.eventDate,
    required this.votingDuration,
    required this.onVotingDurationChanged,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.gris100,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PREVISUALIZACIÓN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gris600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title.isEmpty ? 'Título de la iniciativa' : title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarioNegro,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 14,
                    color: AppColors.gris600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    type,
                    style: TextStyle(fontSize: 12, color: AppColors.gris600),
                  ),
                ],
              ),
              if (eventDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: AppColors.gris600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${eventDate!.day}/${eventDate!.month}/${eventDate!.year}',
                      style: TextStyle(fontSize: 12, color: AppColors.gris600),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Información de Votación',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primarioNegro,
          ),
        ),
        const SizedBox(height: 12),
        _FieldLabel('Duración de Votación'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.primarioBlanco,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gris300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: votingDuration,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: AppColors.gris600),
              items: _votingDurationOptions
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onVotingDurationChanged(v);
              },
            ),
          ),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isSubmitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primarioRojo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Crear Iniciativa',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}
