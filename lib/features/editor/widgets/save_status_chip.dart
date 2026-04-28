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
        final colors = _colorsFor(snap.state);
        final busy = snap.state == EditorSaveState.saving;
        final key =
            '${snap.state.name}-${snap.savedAt?.millisecondsSinceEpoch ?? 0}';

        return AnimatedSwitcher(
          duration: AppMotion.quick,
          switchInCurve: AppMotion.springOut,
          switchOutCurve: AppMotion.standardIn,
          transitionBuilder: _chipTransition,
          child: _StatusChipShell(
            key: ValueKey(key),
            palette: palette,
            bg: colors.$1,
            border: colors.$2,
            fg: colors.$3,
            label: label,
            icon: _iconFor(snap.state),
            busy: busy,
          ),
        );
      },
    );
  }

  Widget _chipTransition(Widget child, Animation<double> animation) {
    final scale = Tween<double>(begin: 0.97, end: 1).animate(
      AppMotion.curved(animation, curve: AppMotion.springOut),
    );
    return AppMotion.fadeSlide(
      animation: animation,
      begin: const Offset(0, 0.08),
      curve: AppMotion.springOut,
      child: ScaleTransition(scale: scale, child: child),
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
        return Icons.check_rounded;
    }
  }

  (Color, Color, Color) _colorsFor(EditorSaveState state) {
    final light = palette.isLight;
    switch (state) {
      case EditorSaveState.saving:
        return (
          palette.statusBg,
          palette.statusFg.withValues(alpha: 0.25),
          palette.statusFg,
        );
      case EditorSaveState.dirty:
        return (
          palette.accent.withValues(alpha: light ? 0.10 : 0.18),
          palette.accent.withValues(alpha: 0.3),
          palette.accent,
        );
      case EditorSaveState.saved:
        return (
          palette.accent.withValues(alpha: light ? 0.08 : 0.14),
          palette.accent.withValues(alpha: 0.25),
          palette.accent,
        );
      case EditorSaveState.idle:
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
        final colors = _colorsFor(snap.state);
        final busy = snap.state == OfflineSyncState.syncing;

        return AnimatedSwitcher(
          duration: AppMotion.quick,
          switchInCurve: AppMotion.springOut,
          switchOutCurve: AppMotion.standardIn,
          transitionBuilder: _chipTransition,
          child: InkWell(
            key: ValueKey(
              '${snap.state.name}-${snap.pendingCount}-${snap.updatedAt?.millisecondsSinceEpoch ?? 0}',
            ),
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: _StatusChipShell(
              palette: palette,
              bg: colors.$1,
              border: colors.$2,
              fg: colors.$3,
              label: label,
              icon: _iconFor(snap.state),
              busy: busy,
            ),
          ),
        );
      },
    );
  }

  Widget _chipTransition(Widget child, Animation<double> animation) {
    final scale = Tween<double>(begin: 0.97, end: 1).animate(
      AppMotion.curved(animation, curve: AppMotion.springOut),
    );
    return AppMotion.fadeSlide(
      animation: animation,
      begin: const Offset(0, 0.08),
      curve: AppMotion.springOut,
      child: ScaleTransition(scale: scale, child: child),
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

class _StatusChipShell extends StatelessWidget {
  const _StatusChipShell({
    super.key,
    required this.palette,
    required this.bg,
    required this.border,
    required this.fg,
    required this.label,
    required this.icon,
    required this.busy,
  });

  final _SheetPalette palette;
  final Color bg;
  final Color border;
  final Color fg;
  final String label;
  final IconData icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.micro,
      curve: AppMotion.standardOut,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: palette.hairline),
        boxShadow: busy
            ? <BoxShadow>[
                BoxShadow(
                  color: fg.withValues(alpha: palette.isLight ? 0.10 : 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            )
          else
            Icon(icon, size: 13, color: fg),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.05,
              letterSpacing: 0.04,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
