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
              leadingDotColor: _dotColorFor(snap.state),
              pulseDot: snap.state != OfflineSyncState.synced,
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
        final pending = snap.pendingCount;
        if (pending > 0) return 'Sin conexión · $pending en cola';
        return 'Sin conexión';
      case OfflineSyncState.pending:
        final pending = snap.pendingCount;
        if (pending > 1) return 'Sin conexión · $pending en cola';
        return 'Sin conexión · 1 en cola';
      case OfflineSyncState.syncing:
        return 'Sincronizando…';
      case OfflineSyncState.synced:
        return 'Sincronizado';
      case OfflineSyncState.failed:
        final pending = snap.pendingCount;
        if (pending > 0) return 'Reintentar · $pending en cola';
        return 'Reintentar sincronización';
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

  Color _dotColorFor(OfflineSyncState state) {
    final light = palette.isLight;
    const greenLight = Color(0xFF34C759);
    const greenDark = Color(0xFF30D158);
    const amberLight = Color(0xFFFF9F0A);
    const amberDark = Color(0xFFFFA726);
    switch (state) {
      case OfflineSyncState.synced:
        return light ? greenLight : greenDark;
      case OfflineSyncState.syncing:
        return palette.accent;
      case OfflineSyncState.pending:
      case OfflineSyncState.offline:
      case OfflineSyncState.failed:
        return light ? amberLight : amberDark;
    }
  }

  (Color, Color, Color) _colorsFor(OfflineSyncState state) {
    final light = palette.isLight;
    final dot = _dotColorFor(state);
    switch (state) {
      case OfflineSyncState.offline:
      case OfflineSyncState.pending:
      case OfflineSyncState.failed:
        return (
          dot.withValues(alpha: light ? 0.12 : 0.20),
          dot.withValues(alpha: light ? 0.42 : 0.55),
          dot,
        );
      case OfflineSyncState.syncing:
        return (
          palette.statusBg,
          palette.statusFg.withValues(alpha: 0.28),
          palette.statusFg,
        );
      case OfflineSyncState.synced:
        return (
          dot.withValues(alpha: light ? 0.10 : 0.18),
          dot.withValues(alpha: light ? 0.35 : 0.45),
          dot,
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
    this.leadingDotColor,
    this.pulseDot = false,
  });

  final _SheetPalette palette;
  final Color bg;
  final Color border;
  final Color fg;
  final String label;
  final IconData icon;
  final bool busy;
  final Color? leadingDotColor;
  final bool pulseDot;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.micro,
      curve: AppMotion.standardOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: palette.hairline),
        boxShadow: busy
            ? <BoxShadow>[
                BoxShadow(
                  color: fg.withValues(alpha: palette.isLight ? 0.12 : 0.24),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingDotColor != null) ...[
            _PulsingDot(
              color: leadingDotColor!,
              pulse: pulseDot && !busy,
            ),
            const SizedBox(width: 6),
          ],
          if (busy)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.9,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            )
          else
            Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          AnimatedDefaultTextStyle(
            duration: AppMotion.quick,
            curve: AppMotion.standardOut,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              height: 1.05,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, required this.pulse});

  final Color color;
  final bool pulse;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.pulse && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final glow = widget.pulse ? 0.35 + 0.45 * t : 0.0;
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: glow > 0
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: glow),
                      blurRadius: 6 + 4 * t,
                      spreadRadius: 0.5 + 1.5 * t,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
