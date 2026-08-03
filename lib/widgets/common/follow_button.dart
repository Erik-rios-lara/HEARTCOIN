import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/common/follow_service.dart';
import '../../theme/app_colors.dart';

/// Botón de "Seguir/Siguiendo" reutilizable para un [targetUserId]
/// (organización o usuario). Se oculta si es el propio usuario.
class FollowButton extends StatefulWidget {
  final String targetUserId;

  /// Usar sobre fondos oscuros/de color (texto y borde blancos).
  final bool light;

  const FollowButton({
    super.key,
    required this.targetUserId,
    this.light = false,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool? _isFollowing;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetUserId != widget.targetUserId) _load();
  }

  Future<void> _load() async {
    try {
      final following = await FollowService.instance.isFollowing(
        widget.targetUserId,
      );
      if (mounted) setState(() => _isFollowing = following);
    } catch (_) {
      // Si falla, el botón simplemente se queda deshabilitado.
    }
  }

  Future<void> _toggle() async {
    if (_busy || _isFollowing == null) return;
    final previous = _isFollowing!;
    setState(() {
      _busy = true;
      _isFollowing = !previous;
    });
    try {
      await FollowService.instance.toggleFollow(widget.targetUserId);
    } catch (_) {
      if (mounted) setState(() => _isFollowing = previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    final following = _isFollowing ?? false;

    final Color foreground;
    final Color borderColor;
    if (widget.light) {
      foreground = following
          ? Colors.white.withValues(alpha: 0.7)
          : Colors.white;
      borderColor = Colors.white.withValues(alpha: following ? 0.4 : 0.9);
    } else {
      foreground = following ? AppColors.gris700 : AppColors.primarioRojo;
      borderColor = following ? AppColors.gris300 : AppColors.primarioRojo;
    }

    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: (_isFollowing == null || _busy) ? null : _toggle,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          foregroundColor: foreground,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          following ? 'Siguiendo' : 'Seguir',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
