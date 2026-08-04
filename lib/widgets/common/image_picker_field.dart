import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_colors.dart';

class PickedImage {
  final String fileName;
  final Uint8List bytes;
  const PickedImage({required this.fileName, required this.bytes});
}

/// Campo para seleccionar una imagen de portada desde galería o cámara,
/// con previsualización. Usado al crear beneficios y servicios.
class ImagePickerField extends StatefulWidget {
  final ValueChanged<PickedImage?> onChanged;
  final String? initialImageUrl;

  const ImagePickerField({
    super.key,
    required this.onChanged,
    this.initialImageUrl,
  });

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  final _picker = ImagePicker();
  PickedImage? _picked;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final picked = PickedImage(fileName: file.name, bytes: bytes);
    setState(() => _picked = picked);
    widget.onChanged(picked);
  }

  void _remove() {
    setState(() => _picked = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    if (_picked != null || widget.initialImageUrl != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: _picked != null
                  ? Image.memory(_picked!.bytes, fit: BoxFit.cover)
                  : Image.network(widget.initialImageUrl!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: GestureDetector(
              onTap: _remove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _PickButton(
            icon: Icons.image_outlined,
            label: 'Galería',
            onTap: () => _pick(ImageSource.gallery),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PickButton(
            icon: Icons.camera_alt_outlined,
            label: 'Cámara',
            onTap: () => _pick(ImageSource.camera),
          ),
        ),
      ],
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primarioBlanco,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gris300),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.gris600, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.gris700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
