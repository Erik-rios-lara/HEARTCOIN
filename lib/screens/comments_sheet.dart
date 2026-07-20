import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/social_service.dart';
import '../theme/app_colors.dart';

Future<void> showCommentsSheet(BuildContext context, {required String postId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CommentsSheet(postId: postId),
  );
}

String _timeAgo(String? isoDate) {
  if (isoDate == null) return '';
  final date = DateTime.tryParse(isoDate);
  if (date == null) return '';
  final diff = DateTime.now().toUtc().difference(date.toUtc());
  if (diff.inSeconds < 60) return 'ahora';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} sem';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mes';
  return '${(diff.inDays / 365).floor()} a';
}

/// Si [content] empieza con "@Nombre " para algún nombre conocido del
/// hilo (`knownNames`), separa esa mención del resto del texto para
/// poder resaltarla al construir el RichText. No hay una columna
/// dedicada a la mención en la base de datos — se reconstruye por
/// coincidencia con los autores que ya participan en el hilo, que es
/// exactamente a quién se puede mencionar al responder.
(String, String)? _splitMention(String content, Set<String> knownNames) {
  String? bestName;
  for (final name in knownNames) {
    if (content.startsWith('@$name ')) {
      if (bestName == null || name.length > bestName.length) bestName = name;
    }
  }
  if (bestName == null) return null;
  final prefixLen = '@$bestName '.length;
  return ('@$bestName', content.substring(prefixLen));
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Map<String, dynamic>? _replyingTo;
  bool _isSending = false;
  final Set<String> _expandedReplies = {};

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startReply(Map<String, dynamic> comment) {
    final name = comment['author_name'] as String? ?? 'Usuario HeartCoin';
    setState(() => _replyingTo = comment);
    _controller.text = '@$name ';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
    _controller.clear();
  }

  void _toggleReplies(String parentId) {
    setState(() {
      if (!_expandedReplies.add(parentId)) _expandedReplies.remove(parentId);
    });
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await SocialService.instance.deleteComment(commentId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el comentario.')),
        );
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await SocialService.instance.addComment(
        postId: widget.postId,
        content: text,
        parentCommentId: _replyingTo?['id'] as String?,
      );
      _controller.clear();
      if (mounted) setState(() => _replyingTo = null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el comentario.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.primarioBlanco,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gris300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Comentarios',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primarioNegro,
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.gris200),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SocialService.instance.commentsStream(widget.postId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primarioRojo,
                        ),
                      );
                    }

                    final all = snapshot.data ?? [];
                    final roots = all
                        .where((c) => c['parent_comment_id'] == null)
                        .toList();
                    final repliesByParent =
                        <String, List<Map<String, dynamic>>>{};
                    for (final c in all) {
                      final parentId = c['parent_comment_id'] as String?;
                      if (parentId != null) {
                        repliesByParent.putIfAbsent(parentId, () => []).add(c);
                      }
                    }
                    final knownNames = all
                        .map((c) => c['author_name'] as String? ?? '')
                        .where((n) => n.isNotEmpty)
                        .toSet();

                    if (roots.isEmpty) {
                      return Center(
                        child: Text(
                          'Aún no hay comentarios.\nSé el primero en comentar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.gris600),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: roots.length,
                      itemBuilder: (context, index) {
                        final comment = roots[index];
                        final commentId = comment['id'] as String;
                        final replies = repliesByParent[commentId] ?? [];
                        return _CommentTile(
                          comment: comment,
                          replies: replies,
                          expanded: _expandedReplies.contains(commentId),
                          onToggleReplies: () => _toggleReplies(commentId),
                          onReply: () => _startReply(comment),
                          knownNames: knownNames,
                          currentUserId: currentUserId,
                          onDelete: _deleteComment,
                        );
                      },
                    );
                  },
                ),
              ),
              if (_replyingTo != null)
                Container(
                  width: double.infinity,
                  color: AppColors.gris100,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Respondiendo a ${_replyingTo!['author_name']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.gris700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.gris600,
                        ),
                      ),
                    ],
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: _replyingTo == null
                                ? 'Escribe un comentario...'
                                : 'Escribe tu respuesta...',
                            filled: true,
                            fillColor: AppColors.gris100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSending ? null : _send,
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: AppColors.primarioRojo,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final List<Map<String, dynamic>> replies;
  final bool expanded;
  final VoidCallback onToggleReplies;
  final VoidCallback onReply;
  final Set<String> knownNames;
  final String? currentUserId;
  final ValueChanged<String> onDelete;

  const _CommentTile({
    required this.comment,
    required this.replies,
    required this.expanded,
    required this.onToggleReplies,
    required this.onReply,
    required this.knownNames,
    required this.currentUserId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentRow(
            comment: comment,
            onReply: onReply,
            showReply: true,
            knownNames: knownNames,
            isOwn: comment['author_id'] == currentUserId,
            onDelete: () => onDelete(comment['id'] as String),
          ),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 6),
              child: GestureDetector(
                onTap: onToggleReplies,
                child: Row(
                  children: [
                    Container(width: 24, height: 1, color: AppColors.gris300),
                    const SizedBox(width: 8),
                    Text(
                      expanded
                          ? 'Ocultar respuestas'
                          : replies.length == 1
                          ? 'Ver 1 respuesta'
                          : 'Ver las ${replies.length} respuestas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gris600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (expanded && replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 8),
              child: Column(
                children: replies
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CommentRow(
                          comment: r,
                          showReply: false,
                          knownNames: knownNames,
                          isOwn: r['author_id'] == currentUserId,
                          onDelete: () => onDelete(r['id'] as String),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatefulWidget {
  final Map<String, dynamic> comment;
  final VoidCallback? onReply;
  final bool showReply;
  final Set<String> knownNames;
  final bool isOwn;
  final VoidCallback onDelete;

  const _CommentRow({
    required this.comment,
    this.onReply,
    required this.showReply,
    required this.knownNames,
    required this.isOwn,
    required this.onDelete,
  });

  @override
  State<_CommentRow> createState() => _CommentRowState();
}

class _CommentRowState extends State<_CommentRow> {
  bool? _liked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _likesCount = (widget.comment['likes_count'] as num?)?.toInt() ?? 0;
    _loadLikeState();
  }

  Future<void> _loadLikeState() async {
    final liked = await SocialService.instance.hasLikedComment(
      widget.comment['id'] as String,
    );
    if (mounted) setState(() => _liked = liked);
  }

  Future<void> _toggleLike() async {
    final commentId = widget.comment['id'] as String;
    final wasLiked = _liked ?? false;
    setState(() {
      _liked = !wasLiked;
      _likesCount += wasLiked ? -1 : 1;
    });
    try {
      await SocialService.instance.toggleLikeComment(commentId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _likesCount += wasLiked ? 1 : -1;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar comentario'),
        content: const Text(
          '¿Seguro que quieres eliminar este comentario? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: AppColors.primarioRojo),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final authorName = comment['author_name'] as String? ?? 'Usuario HeartCoin';
    final authorAvatar = comment['author_avatar_url'] as String?;
    final content = comment['content'] as String? ?? '';
    final mention = _splitMention(content, widget.knownNames);
    final timeLabel = _timeAgo(comment['created_at'] as String?);

    return GestureDetector(
      onLongPress: widget.isOwn ? _confirmDelete : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.gris200,
            backgroundImage: authorAvatar != null
                ? NetworkImage(authorAvatar)
                : null,
            child: authorAvatar == null
                ? Icon(Icons.person, size: 16, color: AppColors.gris600)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primarioNegro,
                    ),
                    children: [
                      TextSpan(
                        text: '$authorName  ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (mention != null) ...[
                        TextSpan(
                          text: '${mention.$1} ',
                          style: TextStyle(
                            color: AppColors.secundarioAzul,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: mention.$2),
                      ] else
                        TextSpan(text: content),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gris600,
                        ),
                      ),
                    if (_likesCount > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        '$_likesCount me gusta',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gris600,
                        ),
                      ),
                    ],
                    if (widget.showReply) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: widget.onReply,
                        child: Text(
                          'Responder',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gris600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _liked == null ? null : _toggleLike,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                (_liked ?? false) ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: (_liked ?? false)
                    ? AppColors.primarioRojo
                    : AppColors.gris600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
