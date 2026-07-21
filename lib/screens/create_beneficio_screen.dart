import 'package:flutter/material.dart';

import '../services/beneficio_service.dart';
import '../services/current_location.dart';
import '../theme/app_colors.dart';
import '../widgets/location_capture_field.dart';

class _BenefitTypeOption {
  final String key;
  final String label;
  final IconData icon;
  const _BenefitTypeOption(this.key, this.label, this.icon);
}

const _benefitTypes = [
  _BenefitTypeOption('descuento', 'Descuento', Icons.percent),
  _BenefitTypeOption('cashback', 'Cashback', Icons.replay_circle_filled),
  _BenefitTypeOption('beca', 'Beca', Icons.school_outlined),
  _BenefitTypeOption('otro', 'Otro', Icons.card_giftcard),
];

class CreateBeneficioScreen extends StatefulWidget {
  const CreateBeneficioScreen({super.key});

  @override
  State<CreateBeneficioScreen> createState() => _CreateBeneficioScreenState();
}

class _CreateBeneficioScreenState extends State<CreateBeneficioScreen> {
  bool _isSubmitting = false;

  String _benefitType = _benefitTypes.first.key;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _termsController = TextEditingController();
  final _hcAmountController = TextEditingController();
  final _maxRedemptionsController = TextEditingController();
  DateTime? _expiresAt;
  LocationCaptureResult? _location;

  bool get _isCashback => _benefitType == 'cashback';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _termsController.dispose();
    _hcAmountController.dispose();
    _maxRedemptionsController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiresAt() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 30)),
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
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _hcAmountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa título, descripción y el valor en HC.'),
        ),
      );
      return;
    }

    final hcAmount = int.tryParse(_hcAmountController.text.trim());
    if (hcAmount == null || hcAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El valor en HC debe ser un número mayor a 0.'),
        ),
      );
      return;
    }

    final maxRedemptions = int.tryParse(_maxRedemptionsController.text.trim());

    setState(() => _isSubmitting = true);
    try {
      await BeneficioService.instance.createBeneficio(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        benefitType: _benefitType,
        hcCost: _isCashback ? null : hcAmount,
        hcReward: _isCashback ? hcAmount : null,
        terms: _termsController.text.trim().isEmpty
            ? null
            : _termsController.text.trim(),
        maxRedemptions: maxRedemptions,
        expiresAt: _expiresAt,
        location: _location?.label,
        latitude: _location?.latitude,
        longitude: _location?.longitude,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo crear el beneficio. Intenta de nuevo.'),
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
        title: const Text('Nuevo beneficio'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const _FieldLabel('Tipo de beneficio'),
          Row(
            children: _benefitTypes.map((option) {
              final isSelected = option.key == _benefitType;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _benefitType = option.key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                          size: 20,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 11,
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

          const _FieldLabel('Título *'),
          _TextInput(
            controller: _titleController,
            hint: _isCashback
                ? 'Ej. Cashback social'
                : 'Ej. 10% de descuento con HeartCoins',
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Descripción *'),
          _TextInput(
            controller: _descriptionController,
            hint: 'Describe el beneficio',
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          _FieldLabel(_isCashback ? 'HC que se otorgan *' : 'Costo en HC *'),
          _TextInput(
            controller: _hcAmountController,
            hint: _isCashback ? 'Ej. 50' : 'Ej. 1000',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Términos y condiciones'),
          _TextInput(
            controller: _termsController,
            hint: 'Opcional',
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Límite de canjes'),
          _TextInput(
            controller: _maxRedemptionsController,
            hint: 'Opcional, ej. 100',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Fecha de vencimiento'),
          _DateField(date: _expiresAt, onTap: _pickExpiresAt),
          const SizedBox(height: 16),

          const _FieldLabel('Ubicación (opcional)'),
          LocationCaptureField(
            onChanged: (result) => setState(() => _location = result),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
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
                      'Publicar beneficio',
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
                    : 'Sin vencimiento',
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
