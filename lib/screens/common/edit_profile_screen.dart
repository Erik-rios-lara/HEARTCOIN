import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/common/media_service.dart';
import '../../theme/app_colors.dart';

const _profileTypeOptions = [
  'Voluntario',
  'Emprendedor',
  'Profesional',
  'Estudiante',
  'Investigador',
  'Otro',
];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _client = Supabase.instance.client;
  final _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSubmitting = false;

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  String _profileType = _profileTypeOptions.first;

  String? _avatarUrl;
  Uint8List? _pickedAvatarBytes;
  String? _pickedAvatarName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final p = await _client
          .from('personal_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (!mounted || p == null) return;
      _fullNameController.text = p['full_name'] as String? ?? '';
      _phoneController.text = p['phone'] as String? ?? '';
      _countryController.text = p['country'] as String? ?? '';
      _cityController.text = p['city'] as String? ?? '';
      _bioController.text = p['bio'] as String? ?? '';
      setState(() {
        _profileType = _profileTypeOptions.contains(p['profile_type'])
            ? p['profile_type'] as String
            : _profileTypeOptions.first;
        _avatarUrl = p['avatar_url'] as String?;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedAvatarBytes = bytes;
      _pickedAvatarName = file.name;
    });
  }

  Future<void> _save() async {
    if (_isSubmitting) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu nombre completo.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      var avatarUrl = _avatarUrl;
      if (_pickedAvatarBytes != null && _pickedAvatarName != null) {
        final uploaded = await MediaService.instance.upload(
          bytes: _pickedAvatarBytes!,
          fileName: _pickedAvatarName!,
        );
        avatarUrl = uploaded.url;
      }

      await _client
          .from('personal_profiles')
          .update({
            'full_name': _fullNameController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            'country': _countryController.text.trim(),
            'city': _cityController.text.trim(),
            'bio': _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            'profile_type': _profileType,
            'avatar_url': avatarUrl,
          })
          .eq('id', userId);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar tu perfil. Intenta de nuevo.'),
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
        title: const Text('Editar perfil'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primarioRojo),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.gris200,
                          backgroundImage: _pickedAvatarBytes != null
                              ? MemoryImage(_pickedAvatarBytes!)
                              : (_avatarUrl != null
                                    ? NetworkImage(_avatarUrl!) as ImageProvider
                                    : null),
                          child:
                              (_pickedAvatarBytes == null && _avatarUrl == null)
                              ? Icon(
                                  Icons.person,
                                  size: 48,
                                  color: AppColors.gris600,
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primarioRojo,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                const _FieldLabel('Nombre completo *'),
                _TextInput(controller: _fullNameController, hint: 'Tu nombre'),
                const SizedBox(height: 16),

                const _FieldLabel('Teléfono'),
                _TextInput(
                  controller: _phoneController,
                  hint: 'Opcional',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('País'),
                          _TextInput(
                            controller: _countryController,
                            hint: 'País',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Ciudad'),
                          _TextInput(
                            controller: _cityController,
                            hint: 'Ciudad',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const _FieldLabel('Tipo de perfil'),
                _Dropdown(
                  value: _profileType,
                  options: _profileTypeOptions,
                  onChanged: (v) => setState(() => _profileType = v),
                ),
                const SizedBox(height: 16),

                const _FieldLabel('Biografía'),
                _TextInput(
                  controller: _bioController,
                  hint: 'Cuéntanos sobre ti',
                  maxLines: 4,
                ),
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
