// lib/screens/corporate/row_comments_sheet.dart
//
// Panel de comentarios por fila. Se usa como bottom sheet desde el editor
// y desde la pantalla de detalle de proyecto. Diseño sobrio, corporativo.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../corporate/corporate_models.dart';
import '../../corporate/corporate_repository.dart';
import '../../corporate/corporate_repository_factory.dart';
import '../../services/auth_service.dart';
import '../../ui/ui.dart';

/// Abre el panel de comentarios de una fila como bottom sheet.
/// Retorna true si se agregó al menos un comentario (útil para refrescar).
Future<bool> showRowCommentsSheet(
  BuildContext context, {
  required String projectId,
  required String sheetLocalId,
  required String rowId,
  required String rowLabel,
  required bool canObserve,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RowCommentsSheet(
      projectId: projectId,
      sheetLocalId: sheetLocalId,
      rowId: rowId,
      rowLabel: rowLabel,
      canObserve: canObserve,
    ),
  );
  return result ?? false;
}

class RowCommentsSheet extends StatefulWidget {
  const RowCommentsSheet({
    super.key,
    required this.projectId,
    required this.sheetLocalId,
    required this.rowId,
    required this.rowLabel,
    required this.canObserve,
  });

  final String projectId;
  final String sheetLocalId;
  final String rowId;
  final String rowLabel;

  /// Si true el usuario puede agregar observaciones formales (rol supervisor+).
  final bool canObserve;

  @override
  State<RowCommentsSheet> createState() => _RowCommentsSheetState();
}

class _RowCommentsSheetState extends State<RowCommentsSheet> {
  late final CorporateRepository _repo;
  List<RowComment> _comments = const <RowComment>[];
  bool _loading = true;
  bool _submitting = false;
  bool _didAdd = false;

  // Formulario de nuevo comentario.
  final TextEditingController _bodyCtrl = TextEditingController();
  RowCommentType _selectedType = RowCommentType.nota;
  String? _replyToId;
  String? _replyToLabel;

  @override
  void initState() {
    super.initState();
    _repo = createCorporateRepository();
    unawaited(_load());
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final comments = await _repo.listRowComments(
        widget.projectId,
        widget.sheetLocalId,
        widget.rowId,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty || _submitting) return;

    final user = AuthService.I.currentUser;
    final authorId = user?.id;
    final authorLabel = user?.email ?? user?.name ?? 'Usuario';
    if (authorId == null || authorId.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final comment = RowComment(
        id: _generateLocalId(),
        projectId: widget.projectId,
        sheetLocalId: widget.sheetLocalId,
        rowId: widget.rowId,
        parentId: _replyToId,
        authorId: authorId,
        authorLabel: authorLabel,
        commentType: _selectedType,
        body: body,
        createdAt: DateTime.now(),
      );
      await _repo.addRowComment(comment);
      _bodyCtrl.clear();
      setState(() {
        _replyToId = null;
        _replyToLabel = null;
        _submitting = false;
        _didAdd = true;
      });
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }

  void _startReply(RowComment parent) {
    setState(() {
      _replyToId = parent.id;
      _replyToLabel = parent.authorLabel;
      _selectedType = RowCommentType.respuesta;
    });
    _bodyCtrl.selection =
        TextSelection.collapsed(offset: _bodyCtrl.text.length);
  }

  void _clearReply() {
    setState(() {
      _replyToId = null;
      _replyToLabel = null;
      if (_selectedType == RowCommentType.respuesta) {
        _selectedType = RowCommentType.nota;
      }
    });
  }

  String _generateLocalId() {
    return 'local_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: t.colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            rowLabel: widget.rowLabel,
            commentCount: _comments.length,
            onClose: () => Navigator.of(context).pop(_didAdd),
          ),
          const Divider(height: 1),
          Flexible(
            child: _loading
                ? const _LoadingBody()
                : _comments.isEmpty
                    ? const _EmptyBody()
                    : _CommentList(
                        comments: _comments,
                        onReply: _startReply,
                      ),
          ),
          const Divider(height: 1),
          _CommentInput(
            controller: _bodyCtrl,
            selectedType: _selectedType,
            canObserve: widget.canObserve,
            replyToLabel: _replyToLabel,
            submitting: _submitting,
            onTypeChanged: (t) => setState(() => _selectedType = t),
            onClearReply: _clearReply,
            onSubmit: _submit,
          ),
          SizedBox(height: mq.viewInsets.bottom + mq.padding.bottom + 8),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.rowLabel,
    required this.commentCount,
    required this.onClose,
  });

  final String rowLabel;
  final int commentCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.lg,
        t.spacing.md,
        t.spacing.sm,
        t.spacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.colors.accentMuted,
              borderRadius: BorderRadius.circular(t.radii.md),
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                color: t.colors.accent, size: 20),
          ),
          SizedBox(width: t.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comentarios de fila',
                  style: t.text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  rowLabel.isNotEmpty ? rowLabel : 'Fila sin identificador',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.bodySmall
                      ?.copyWith(color: t.colors.textSecondary),
                ),
              ],
            ),
          ),
          if (commentCount > 0)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: t.spacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: t.colors.accentMuted,
                borderRadius: BorderRadius.circular(t.radii.pill),
              ),
              child: Text(
                '$commentCount',
                style: t.text.bodySmall?.copyWith(
                  color: t.colors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.all(t.spacing.xl),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.all(t.spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 36, color: t.colors.textSecondary),
          SizedBox(height: t.spacing.md),
          Text(
            'Sin comentarios todavía',
            style: t.text.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: t.spacing.xs),
          Text(
            'Agregá una observación, nota o respuesta para esta fila.',
            textAlign: TextAlign.center,
            style: t.text.bodySmall
                ?.copyWith(color: t.colors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CommentList extends StatelessWidget {
  const _CommentList({required this.comments, required this.onReply});

  final List<RowComment> comments;
  final void Function(RowComment) onReply;

  @override
  Widget build(BuildContext context) {
    // Separar raíces y respuestas.
    final roots = comments.where((c) => c.parentId == null).toList();
    final repliesByParent = <String, List<RowComment>>{};
    for (final c in comments) {
      if (c.parentId != null) {
        repliesByParent.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: roots.length,
      itemBuilder: (context, i) {
        final root = roots[i];
        final replies = repliesByParent[root.id] ?? const <RowComment>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentTile(comment: root, isReply: false, onReply: onReply),
            for (final reply in replies)
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child:
                    _CommentTile(comment: reply, isReply: true, onReply: null),
              ),
          ],
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isReply,
    required this.onReply,
  });

  final RowComment comment;
  final bool isReply;
  final void Function(RowComment)? onReply;

  Color _typeColor(BuildContext ctx, RowCommentType type) {
    final t = ctx.tokens;
    return switch (type) {
      RowCommentType.observacion => t.colors.dangerFg,
      RowCommentType.resolucion => t.colors.successFg,
      RowCommentType.respuesta => t.colors.accent,
      RowCommentType.nota => t.colors.textSecondary,
    };
  }

  IconData _typeIcon(RowCommentType type) => switch (type) {
        RowCommentType.observacion => Icons.flag_rounded,
        RowCommentType.resolucion => Icons.check_circle_rounded,
        RowCommentType.respuesta => Icons.reply_rounded,
        RowCommentType.nota => Icons.sticky_note_2_rounded,
      };

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes}m';
    if (diff.inDays < 1) return 'hace ${diff.inHours}h';
    if (diff.inDays < 30) return 'hace ${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final typeColor = _typeColor(context, comment.commentType);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.lg,
        vertical: t.spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_typeIcon(comment.commentType),
                  size: 13, color: typeColor),
              SizedBox(width: t.spacing.xs),
              Text(
                comment.commentType.label,
                style: t.text.labelSmall?.copyWith(
                  color: typeColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: t.spacing.sm),
              Expanded(
                child: Text(
                  comment.authorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.labelSmall?.copyWith(
                    color: t.colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatTime(comment.createdAt),
                style: t.text.labelSmall
                    ?.copyWith(color: t.colors.textSecondary),
              ),
            ],
          ),
          SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: t.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(t.radii.md),
              border: Border(
                left: BorderSide(color: typeColor, width: 3),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              t.spacing.sm,
              t.spacing.sm,
              t.spacing.sm,
              t.spacing.sm,
            ),
            child: Text(
              comment.body,
              style: t.text.bodySmall?.copyWith(height: 1.4),
            ),
          ),
          if (!isReply && onReply != null)
            TextButton.icon(
              onPressed: () => onReply!(comment),
              icon: Icon(Icons.reply_rounded, size: 14,
                  color: t.colors.textSecondary),
              label: Text(
                'Responder',
                style: t.text.labelSmall
                    ?.copyWith(color: t.colors.textSecondary),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: t.spacing.sm,
                  vertical: 2,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          SizedBox(height: t.spacing.xs),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.selectedType,
    required this.canObserve,
    required this.replyToLabel,
    required this.submitting,
    required this.onTypeChanged,
    required this.onClearReply,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final RowCommentType selectedType;
  final bool canObserve;
  final String? replyToLabel;
  final bool submitting;
  final ValueChanged<RowCommentType> onTypeChanged;
  final VoidCallback onClearReply;
  final VoidCallback onSubmit;

  List<RowCommentType> _availableTypes() {
    if (canObserve) {
      return RowCommentType.values;
    }
    return const [RowCommentType.respuesta, RowCommentType.nota];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyToLabel != null)
            Padding(
              padding: EdgeInsets.only(bottom: t.spacing.xs),
              child: Row(
                children: [
                  Icon(Icons.reply_rounded,
                      size: 14, color: t.colors.accent),
                  SizedBox(width: t.spacing.xs),
                  Expanded(
                    child: Text(
                      'Respondiendo a $replyToLabel',
                      style: t.text.labelSmall
                          ?.copyWith(color: t.colors.accent),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onClearReply,
                    child: Icon(Icons.close_rounded,
                        size: 14, color: t.colors.textSecondary),
                  ),
                ],
              ),
            ),
          // Tipo de comentario.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final type in _availableTypes())
                  Padding(
                    padding: EdgeInsets.only(right: t.spacing.xs),
                    child: _TypeChip(
                      type: type,
                      selected: selectedType == type,
                      onTap: () => onTypeChanged(type),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: t.spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: 3,
                  minLines: 1,
                  enabled: !submitting,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: 'Escribí tu ${selectedType.label.toLowerCase()}…',
                    hintStyle: t.text.bodySmall
                        ?.copyWith(color: t.colors.textSecondary),
                    filled: true,
                    fillColor: t.colors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.radii.md),
                      borderSide: BorderSide(color: t.colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.radii.md),
                      borderSide: BorderSide(color: t.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(t.radii.md),
                      borderSide:
                          BorderSide(color: t.colors.accent, width: 1.5),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: t.spacing.md,
                      vertical: t.spacing.sm,
                    ),
                    isDense: true,
                  ),
                  style: t.text.bodySmall,
                ),
              ),
              SizedBox(width: t.spacing.sm),
              SizedBox(
                width: 44,
                height: 44,
                child: submitting
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : FilledButton(
                        onPressed: onSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: t.colors.accent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(t.radii.md),
                          ),
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: t.colors.isLight ? Colors.white : Colors.black,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final RowCommentType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: t.spacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: selected ? t.colors.accent : t.colors.surfaceMuted,
          borderRadius: BorderRadius.circular(t.radii.pill),
          border: Border.all(
            color: selected
                ? t.colors.accent
                : t.colors.border,
          ),
        ),
        child: Text(
          type.label,
          style: t.text.labelSmall?.copyWith(
            color: selected
                ? (t.colors.isLight ? Colors.white : Colors.black)
                : t.colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
