part of '../editor_screen.dart';

class SaveStatusChip extends StatelessWidget {
  const SaveStatusChip({
    super.key,
    required this.palette,
    required this.status,
  });

  final _SheetPalette palette;
  final ValueListenable<EditorSaveSnapshot> status;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EditorSaveSnapshot>(
      valueListenable: status,
      builder: (context, snap, _) {
        final label = _labelFor(snap);
        final icon = _iconFor(snap.state);
        final colors = _colorsFor(snap.state);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) {
            final offset = Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(anim);
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(position: offset, child: child),
            );
          },
          child: Container(
            key: ValueKey(snap.state),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.$1,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.$2, width: palette.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: colors.$3),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: colors.$3,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _labelFor(EditorSaveSnapshot snap) {
    switch (snap.state) {
      case EditorSaveState.saving:
        return 'Guardando...';
      case EditorSaveState.dirty:
        return 'Sin guardar';
      case EditorSaveState.saved:
        final d = snap.savedAt;
        if (d == null) return 'Guardado';
        final hh = d.hour.toString().padLeft(2, '0');
        final mm = d.minute.toString().padLeft(2, '0');
        return 'Guardado $hh:$mm';
      case EditorSaveState.idle:
      default:
        return 'Listo';
    }
  }

  IconData _iconFor(EditorSaveState state) {
    switch (state) {
      case EditorSaveState.saving:
        return Icons.sync_rounded;
      case EditorSaveState.dirty:
        return Icons.edit_rounded;
      case EditorSaveState.saved:
        return Icons.check_circle_outline_rounded;
      case EditorSaveState.idle:
      default:
        return Icons.check_rounded;
    }
  }

  (Color, Color, Color) _colorsFor(EditorSaveState state) {
    final light = palette.isLight;
    switch (state) {
      case EditorSaveState.saving:
        return (
          palette.statusBg,
          palette.statusFg.withOpacity(0.25),
          palette.statusFg,
        );
      case EditorSaveState.dirty:
        return (
          palette.accent.withOpacity(light ? 0.10 : 0.18),
          palette.accent.withOpacity(0.3),
          palette.accent,
        );
      case EditorSaveState.saved:
        return (
          palette.accent.withOpacity(light ? 0.08 : 0.14),
          palette.accent.withOpacity(0.25),
          palette.accent,
        );
      case EditorSaveState.idle:
      default:
        return (
          palette.hintBg,
          palette.border,
          palette.fgMuted,
        );
    }
  }
}

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    super.key,
    required this.palette,
    required this.status,
    this.onTap,
  });

  final _SheetPalette palette;
  final ValueListenable<OfflineSyncSnapshot> status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineSyncSnapshot>(
      valueListenable: status,
      builder: (context, snap, _) {
        final label = _labelFor(snap);
        final icon = _iconFor(snap.state);
        final colors = _colorsFor(snap.state);

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.$1,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.$2, width: palette.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: colors.$3),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: colors.$3,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _labelFor(OfflineSyncSnapshot snap) {
    switch (snap.state) {
      case OfflineSyncState.offline:
        return 'Offline / Pendiente sync';
      case OfflineSyncState.pending:
        final pending = snap.pendingCount;
        if (pending > 1) return 'Pendiente sync ($pending)';
        return 'Pendiente sync';
      case OfflineSyncState.syncing:
        return 'Sincronizando...';
      case OfflineSyncState.synced:
        return 'Sincronizado';
      case OfflineSyncState.failed:
        return 'Fallo (reintentar)';
    }
  }

  IconData _iconFor(OfflineSyncState state) {
    switch (state) {
      case OfflineSyncState.offline:
        return Icons.cloud_off_outlined;
      case OfflineSyncState.pending:
        return Icons.cloud_upload_outlined;
      case OfflineSyncState.syncing:
        return Icons.sync_rounded;
      case OfflineSyncState.synced:
        return Icons.cloud_done_outlined;
      case OfflineSyncState.failed:
        return Icons.sync_problem_rounded;
    }
  }

  (Color, Color, Color) _colorsFor(OfflineSyncState state) {
    switch (state) {
      case OfflineSyncState.offline:
        return (
          palette.hintBg,
          palette.border,
          palette.fgMuted,
        );
      case OfflineSyncState.pending:
        return (
          palette.selectionFill,
          palette.selectionBorder.withValues(alpha: 0.4),
          palette.selectionBorder,
        );
      case OfflineSyncState.syncing:
        return (
          palette.statusBg,
          palette.statusFg.withValues(alpha: 0.28),
          palette.statusFg,
        );
      case OfflineSyncState.synced:
        return (
          palette.hintBg,
          palette.border,
          palette.fgMuted,
        );
      case OfflineSyncState.failed:
        return (
          palette.selectionFill,
          palette.selectionBorder,
          palette.selectionBorder,
        );
    }
  }
}
