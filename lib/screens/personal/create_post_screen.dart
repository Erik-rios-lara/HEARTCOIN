import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/common/current_location.dart';
import '../../services/common/media_service.dart';
import '../../theme/app_colors.dart';
import 'select_iniciativa_screen.dart';

class _PickedFile {
  final String name;
  final Uint8List bytes;
  const _PickedFile({required this.name, required this.bytes});
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  Map<String, dynamic>? _selectedIniciativa;
  _PickedFile? _pickedImage;
  final List<_PickedFile> _pickedDocuments = [];

  bool _isFetchingLocation = false;
  String? _locationLabel;

  bool _isPosting = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _pickedImage = _PickedFile(name: file.name, bytes: bytes));
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
      ],
    );
    if (result == null) return;

    setState(() {
      for (final file in result.files) {
        if (file.bytes != null) {
          _pickedDocuments.add(
            _PickedFile(name: file.name, bytes: file.bytes!),
          );
        }
      }
    });
  }

  Future<void> _addLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final result = await captureCurrentLocation();
      if (!mounted) return;
      setState(() => _locationLabel = result.label ?? 'Ubicación actual');
    } on LocationPermissionDeniedException {
      _showMessage('Permiso de ubicación denegado.');
    } on LocationServiceDisabledException {
      _showMessage('Activa el GPS para agregar tu ubicación.');
    } catch (_) {
      _showMessage('No se pudo obtener tu ubicación.');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _selectIniciativa() async {
    final selected = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const SelectIniciativaScreen()),
    );
    if (selected != null) setState(() => _selectedIniciativa = selected);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onPublish() async {
    if (_isPosting) return;

    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      _showMessage('Escribe algo para compartir.');
      return;
    }

    setState(() => _isPosting = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        _showMessage('Tu sesión expiró. Vuelve a iniciar sesión.');
        return;
      }

      final profile = await client
          .from('personal_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      String? imageUrl;
      int? imageFileId;
      if (_pickedImage != null) {
        final uploaded = await MediaService.instance.upload(
          bytes: _pickedImage!.bytes,
          fileName: _pickedImage!.name,
        );
        imageUrl = uploaded.url;
        imageFileId = uploaded.fileId;
      }

      final documentUrls = <String>[];
      final documentNames = <String>[];
      for (final document in _pickedDocuments) {
        final uploaded = await MediaService.instance.upload(
          bytes: document.bytes,
          fileName: document.name,
        );
        documentUrls.add(uploaded.url);
        documentNames.add(document.name);
      }

      await client.from('publicaciones').insert({
        'author_id': userId,
        'author_name': profile?['full_name'] as String? ?? 'Usuario HeartCoin',
        'author_avatar_url': profile?['avatar_url'] as String?,
        'caption': caption,
        'image_url': imageUrl,
        'image_file_id': imageFileId,
        'iniciativa_id': _selectedIniciativa?['id'],
        'initiative_name': _selectedIniciativa?['title'],
        'location': _locationLabel,
        'document_urls': documentUrls,
        'document_names': documentNames,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
    } on MediaUploadException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('No se pudo publicar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gris100,
      appBar: AppBar(
        backgroundColor: AppColors.primarioRojo,
        foregroundColor: AppColors.primarioBlanco,
        elevation: 0,
        title: const Text('Nueva publicación'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '¿Qué quieres compartir?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primarioNegro,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primarioBlanco,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gris300),
              ),
              child: TextField(
                controller: _captionController,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                  hintText: 'Cuéntale a la comunidad qué estás haciendo...',
                  hintStyle: TextStyle(color: AppColors.gris600),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Relacionar con iniciativa',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primarioNegro,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _selectIniciativa,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primarioBlanco,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gris300),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(Icons.favorite, size: 18, color: AppColors.primarioRojo),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedIniciativa?['title'] as String? ??
                            'Ninguna (opcional)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedIniciativa != null
                              ? AppColors.primarioNegro
                              : AppColors.gris600,
                        ),
                      ),
                    ),
                    if (_selectedIniciativa != null)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _selectedIniciativa = null),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.gris600,
                        ),
                      )
                    else
                      Icon(Icons.chevron_right, color: AppColors.gris600),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Agregar multimedia',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primarioNegro,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MediaActionButton(
                  icon: Icons.image_outlined,
                  label: 'Imágenes',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                const SizedBox(width: 12),
                _MediaActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Cámara',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 12),
                _MediaActionButton(
                  icon: Icons.insert_drive_file_outlined,
                  label: 'Documentos',
                  onTap: _pickDocuments,
                ),
              ],
            ),

            if (_pickedImage != null) ...[
              const SizedBox(height: 16),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      _pickedImage!.bytes,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _RemoveChip(
                      onTap: () => setState(() => _pickedImage = null),
                    ),
                  ),
                ],
              ),
            ],

            if (_pickedDocuments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pickedDocuments
                    .map(
                      (doc) => Chip(
                        backgroundColor: AppColors.gris200,
                        label: Text(
                          doc.name,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () =>
                            setState(() => _pickedDocuments.remove(doc)),
                      ),
                    )
                    .toList(),
              ),
            ],

            const SizedBox(height: 24),
            Text(
              'Ubicación',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primarioNegro,
              ),
            ),
            const SizedBox(height: 10),
            if (_locationLabel == null)
              OutlinedButton.icon(
                onPressed: _isFetchingLocation ? null : _addLocation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primarioRojo,
                  side: const BorderSide(color: AppColors.primarioRojo),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isFetchingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on_outlined),
                label: const Text('Agregar ubicación'),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.rojoClaro1.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.primarioRojo,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationLabel!,
                        style: TextStyle(color: AppColors.primarioNegro),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _locationLabel = null),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.gris600,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isPosting ? null : _onPublish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primarioRojo,
                  foregroundColor: AppColors.primarioBlanco,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isPosting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Publicar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primarioBlanco,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gris300),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primarioRojo, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.gris700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveChip extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 16),
      ),
    );
  }
}
