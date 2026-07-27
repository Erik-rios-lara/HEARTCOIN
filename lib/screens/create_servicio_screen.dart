import 'package:flutter/material.dart';

import '../services/current_location.dart';
import '../services/servicio_service.dart';
import '../theme/app_colors.dart';
import '../widgets/location_capture_field.dart';

const _categoryOptions = [
  'Consultoría',
  'Tecnología',
  'Diseño',
  'Legal',
  'Marketing',
  'Capacitación',
  'Otro',
];

class CreateServicioScreen extends StatefulWidget {
  const CreateServicioScreen({super.key});

  @override
  State<CreateServicioScreen> createState() => _CreateServicioScreenState();
}

const _pricingTypeOptions = [
  ('costo', 'Cuesta HC', Icons.remove_circle_outline),
  ('cashback', 'Da HC de regreso', Icons.replay_circle_filled),
];

class _CreateServicioScreenState extends State<CreateServicioScreen> {
  bool _isSubmitting = false;
  String _category = _categoryOptions.first;
  String _pricingType = 'costo';
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hcAmountController = TextEditingController();
  final _maxRedemptionsController = TextEditingController();
  LocationCaptureResult? _location;
  bool _destacado = false;

  bool get _isCashback => _pricingType == 'cashback';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hcAmountController.dispose();
    _maxRedemptionsController.dispose();
    super.dispose();
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
      await ServicioService.instance.createServicio(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        pricingType: _pricingType,
        hcCost: _isCashback ? null : hcAmount,
        hcReward: _isCashback ? hcAmount : null,
        maxRedemptions: maxRedemptions,
        location: _location?.label,
        latitude: _location?.latitude,
        longitude: _location?.longitude,
        destacado: _destacado,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo publicar el servicio. Intenta de nuevo.'),
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
        title: const Text('Nuevo servicio'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const _FieldLabel('Categoría'),
          _Dropdown(
            value: _category,
            options: _categoryOptions,
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Título *'),
          _TextInput(
            controller: _titleController,
            hint: 'Ej. Asesoría legal para emprendedores',
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Descripción *'),
          _TextInput(
            controller: _descriptionController,
            hint: 'Describe el servicio que ofrece tu empresa',
            maxLines: 4,
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Tipo de recompensa'),
          Row(
            children: _pricingTypeOptions.map((option) {
              final (key, label, icon) = option;
              final isSelected = key == _pricingType;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _pricingType = key),
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
                          icon,
                          color: isSelected ? Colors.white : AppColors.gris600,
                          size: 20,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
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
          const SizedBox(height: 16),

          _FieldLabel(_isCashback ? 'HC que se otorgan *' : 'Costo en HC *'),
          _TextInput(
            controller: _hcAmountController,
            hint: _isCashback ? 'Ej. 50' : 'Ej. 300',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Límite de canjes'),
          _TextInput(
            controller: _maxRedemptionsController,
            hint: 'Opcional, ej. 50',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Ubicación (opcional)'),
          LocationCaptureField(
            onChanged: (result) => setState(() => _location = result),
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            value: _destacado,
            onChanged: (v) => setState(() => _destacado = v),
            activeThumbColor: AppColors.primarioRojo,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Marcar como destacado',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Aparece en la sección "Destacados" de la billetera.',
              style: TextStyle(fontSize: 12),
            ),
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
                      'Publicar servicio',
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
