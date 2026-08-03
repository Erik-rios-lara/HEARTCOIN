import 'package:flutter/material.dart';

import '../../services/common/saved_items_service.dart';

/// Ícono de "guardar" reutilizable para una iniciativa o votación.
class SaveButton extends StatefulWidget {
  final String itemType;
  final String itemId;
  final Color color;

  /// Versión pequeña sin fondo circular, para usar dentro de filas
  /// compactas (tarjetas de listas).
  final bool compact;

  const SaveButton({
    super.key,
    required this.itemType,
    required this.itemId,
    this.color = Colors.white,
    this.compact = false,
  });

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool? _isSaved;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await SavedItemsService.instance.isSaved(
        widget.itemType,
        widget.itemId,
      );
      if (mounted) setState(() => _isSaved = saved);
    } catch (_) {
      // Si falla, el ícono simplemente se queda deshabilitado.
    }
  }

  Future<void> _toggle() async {
    if (_busy || _isSaved == null) return;
    final previous = _isSaved!;
    setState(() {
      _busy = true;
      _isSaved = !previous;
    });
    try {
      await SavedItemsService.instance.toggleSave(
        widget.itemType,
        widget.itemId,
      );
    } catch (_) {
      if (mounted) setState(() => _isSaved = previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _isSaved ?? false;
    final icon = Icon(
      saved ? Icons.bookmark : Icons.bookmark_border,
      color: widget.color,
      size: widget.compact ? 18 : 20,
    );

    if (widget.compact) {
      return GestureDetector(
        onTap: (_isSaved == null || _busy) ? null : _toggle,
        child: Padding(padding: const EdgeInsets.all(2), child: icon),
      );
    }

    return GestureDetector(
      onTap: (_isSaved == null || _busy) ? null : _toggle,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: icon,
      ),
    );
  }
}
