import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

class _Objective {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;

  const _Objective({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const _objectives = [
  _Objective(
    key: 'vivienda',
    title: 'La casa de mis sueños',
    subtitle:
        'Ahorra para el enganche de tu vivienda con proveedores inmobiliarios asociados.',
    icon: Icons.home_outlined,
  ),
  _Objective(
    key: 'educacion',
    title: 'Educación',
    subtitle:
        'Financia tus estudios o los de alguien más con instituciones educativas verificadas.',
    icon: Icons.school_outlined,
  ),
  _Objective(
    key: 'vehiculo',
    title: 'Vehículo',
    subtitle: 'Consigue tu auto o moto con nuestros concesionarios aliados.',
    icon: Icons.directions_car_outlined,
  ),
  _Objective(
    key: 'otro',
    title: 'Otro objetivo',
    subtitle:
        'Define un objetivo personalizado y encuentra proveedores que puedan ayudarte.',
    icon: Icons.flag_outlined,
  ),
];

class CreateIniciativaAhorroScreen extends StatefulWidget {
  const CreateIniciativaAhorroScreen({super.key});

  @override
  State<CreateIniciativaAhorroScreen> createState() =>
      _CreateIniciativaAhorroScreenState();
}

class _CreateIniciativaAhorroScreenState
    extends State<CreateIniciativaAhorroScreen> {
  final _client = Supabase.instance.client;

  int _step = 0;
  _Objective? _selectedObjective;
  Map<String, dynamic>? _selectedProvider;

  bool _isLoadingProviders = false;
  List<Map<String, dynamic>> _providers = [];

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _targetDate;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFormFieldChanged);
    _amountController.addListener(_onFormFieldChanged);
  }

  void _onFormFieldChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders(String objectiveType) async {
    setState(() => _isLoadingProviders = true);
    try {
      final rows = await _client
          .from('proveedores')
          .select()
          .eq('objective_type', objectiveType)
          .order('rating', ascending: false);
      if (!mounted) return;
      setState(() => _providers = (rows as List).cast<Map<String, dynamic>>());
    } finally {
      if (mounted) setState(() => _isLoadingProviders = false);
    }
  }

  void _goToStep(int step) {
    setState(() => _step = step);
  }

  void _selectObjective(_Objective objective) {
    setState(() {
      _selectedObjective = objective;
      _selectedProvider = null;
    });
  }

  void _continueFromObjective() {
    if (_selectedObjective == null) return;
    _loadProviders(_selectedObjective!.key);
    _goToStep(1);
  }

  void _selectProvider(Map<String, dynamic> provider) {
    setState(() => _selectedProvider = provider);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
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
    if (picked != null) setState(() => _targetDate = picked);
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _amountController.text.trim().isNotEmpty &&
      _targetDate != null &&
      !_isSubmitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSubmitting = true);
    try {
      await _client.from('iniciativas').insert({
        'title': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': 'Ahorro',
        'author_id': userId,
        'objective_type': _selectedObjective?.key,
        'provider_id': _selectedProvider?['id'],
        'provider_name': _selectedProvider?['name'],
        'provider_rating': _selectedProvider?['rating'],
        'target_amount': double.tryParse(
          _amountController.text.trim().replaceAll(',', ''),
        ),
        'target_date': _targetDate?.toIso8601String().split('T').first,
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

  void _onBackPressed() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
    } else {
      _goToStep(_step - 1);
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
                  Text(
                    'Crear nueva Iniciativa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primarioNegro,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: _StepperHeader(currentStep: _step),
            ),
            Expanded(
              child: switch (_step) {
                0 => _ObjectiveStep(
                  selected: _selectedObjective,
                  onSelect: _selectObjective,
                  onContinue: _continueFromObjective,
                ),
                1 => _ProviderStep(
                  objective: _selectedObjective!,
                  providers: _providers,
                  isLoading: _isLoadingProviders,
                  selected: _selectedProvider,
                  onSelect: _selectProvider,
                  onChangeObjective: () => _goToStep(0),
                  onContinue: _selectedProvider == null
                      ? null
                      : () => _goToStep(2),
                ),
                _ => _DetailsStep(
                  objective: _selectedObjective!,
                  provider: _selectedProvider!,
                  nameController: _nameController,
                  descriptionController: _descriptionController,
                  amountController: _amountController,
                  targetDate: _targetDate,
                  onPickDate: _pickDate,
                  onChangeProvider: () => _goToStep(1),
                  canSubmit: _canSubmit,
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
  const _StepperHeader({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
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

class _ObjectiveStep extends StatelessWidget {
  final _Objective? selected;
  final ValueChanged<_Objective> onSelect;
  final VoidCallback onContinue;

  const _ObjectiveStep({
    required this.selected,
    required this.onSelect,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '¿Qué quieres lograr?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primarioNegro,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            itemCount: _objectives.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final objective = _objectives[index];
              final isSelected = selected?.key == objective.key;
              return GestureDetector(
                onTap: () => onSelect(objective),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primarioRojo
                        : AppColors.primarioBlanco,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primarioRojo
                          : AppColors.gris300,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected ? Colors.white : AppColors.gris400,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              objective.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primarioNegro,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              objective.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : AppColors.gris600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: selected == null ? null : onContinue,
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
          ),
        ),
      ],
    );
  }
}

class _ProviderStep extends StatelessWidget {
  final _Objective objective;
  final List<Map<String, dynamic>> providers;
  final bool isLoading;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback onChangeObjective;
  final VoidCallback? onContinue;

  const _ProviderStep({
    required this.objective,
    required this.providers,
    required this.isLoading,
    required this.selected,
    required this.onSelect,
    required this.onChangeObjective,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelectionBanner(
                label: 'Objetivo seleccionado:',
                value: objective.title,
                onChange: onChangeObjective,
              ),
              const SizedBox(height: 20),
              Text(
                'Selecciona un proveedor',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarioNegro,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primarioRojo,
                  ),
                )
              : providers.isEmpty
              ? Center(
                  child: Text(
                    'No hay proveedores disponibles por ahora.',
                    style: TextStyle(color: AppColors.gris600),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: providers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final provider = providers[index];
                    final isSelected = selected?['id'] == provider['id'];
                    final rating =
                        (provider['rating'] as num?)?.toDouble() ?? 0;
                    return GestureDetector(
                      onTap: () => onSelect(provider),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.rojoClaro1.withValues(alpha: 0.12)
                              : AppColors.primarioBlanco,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primarioRojo
                                : AppColors.gris300,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? AppColors.primarioRojo
                                  : AppColors.gris400,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          provider['name'] as String? ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primarioNegro,
                                          ),
                                        ),
                                      ),
                                      _StarRating(rating: rating),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    provider['description'] as String? ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gris600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onContinue,
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
          ),
        ),
      ],
    );
  }
}

class _DetailsStep extends StatelessWidget {
  final _Objective objective;
  final Map<String, dynamic> provider;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController amountController;
  final DateTime? targetDate;
  final VoidCallback onPickDate;
  final VoidCallback onChangeProvider;
  final bool canSubmit;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _DetailsStep({
    required this.objective,
    required this.provider,
    required this.nameController,
    required this.descriptionController,
    required this.amountController,
    required this.targetDate,
    required this.onPickDate,
    required this.onChangeProvider,
    required this.canSubmit,
    required this.isSubmitting,
    required this.onSubmit,
  });

  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  String _formatDate(DateTime date) {
    final weekday = _weekdays[date.weekday - 1];
    final month = _months[date.month - 1];
    return '${weekday[0].toUpperCase()}${weekday.substring(1)}, ${date.day} de $month';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.rojoClaro1.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primarioRojo.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Objetivo: ${objective.title}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primarioNegro,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Proveedor: ${provider['name']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primarioNegro,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onChangeProvider,
                child: const Text(
                  'Cambiar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primarioRojo,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Detalles de tu meta',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.primarioNegro,
          ),
        ),
        const SizedBox(height: 16),

        const _FieldLabel('Nombre de la meta'),
        _TextInput(
          controller: nameController,
          hint: 'Ej. Enganche para mi casa',
        ),
        const SizedBox(height: 16),

        const _FieldLabel('Descripción'),
        _TextInput(
          controller: descriptionController,
          hint: 'Cuéntanos más sobre tu meta...',
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        const _FieldLabel('Meta de ahorro'),
        _TextInput(
          controller: amountController,
          hint: '\$15,000',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 4),
        Text(
          'La cantidad está sujeta a observaciones del proveedor.',
          style: TextStyle(fontSize: 11, color: AppColors.gris600),
        ),
        const SizedBox(height: 16),

        const _FieldLabel('¿Cuándo quieres alcanzar esta meta?'),
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
                    targetDate != null
                        ? _formatDate(targetDate!)
                        : 'Selecciona una fecha',
                    style: TextStyle(
                      fontSize: 14,
                      color: targetDate != null
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

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: canSubmit ? onSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primarioRojo,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.gris300,
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

class _SelectionBanner extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onChange;

  const _SelectionBanner({
    required this.label,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.rojoClaro1.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primarioRojo.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: AppColors.primarioNegro),
                children: [
                  TextSpan(text: '$label '),
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: onChange,
            child: const Text(
              'Cambiar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primarioRojo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double rating;
  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          return Icon(
            i < rating.round() ? Icons.star : Icons.star_border,
            size: 12,
            color: AppColors.secundarioAmarillo,
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: 11, color: AppColors.gris600),
        ),
      ],
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
