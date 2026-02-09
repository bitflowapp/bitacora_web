part of '../editor_screen.dart';

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(text,
          style:
              TextStyle(color: fg, fontWeight: FontWeight.w900, height: 1.05)),
    );
  }
}

class _MobileQuickActionsBar extends StatelessWidget {
  const _MobileQuickActionsBar({
    required this.palette,
    required this.sensorsEnabled,
    required this.onGps,
    required this.onPhoto,
    required this.onVideo,
    required this.onAudio,
    required this.onFile,
    required this.onExport,
    required this.onShare,
    required this.onDensity,
  });

  final _SheetPalette palette;
  final bool sensorsEnabled;
  final VoidCallback onGps;
  final VoidCallback onPhoto;
  final VoidCallback onVideo;
  final VoidCallback onAudio;
  final VoidCallback onFile;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onDensity;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final bg =
        t.colors.surfaceElevated.withOpacity(palette.isLight ? 0.92 : 0.78);

    return AppleCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      radius: t.radii.xl,
      color: bg,
      borderColor: t.colors.border,
      shadows: t.shadows.soft,
      child: SizedBox(
        height: _kMobileQuickBarH,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppleButton(
                icon: Icons.my_location_rounded,
                label: 'GPS',
                dense: true,
                onPressed: onGps,
                enabled: sensorsEnabled,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.photo_camera_outlined,
                label: 'Camara',
                dense: true,
                onPressed: onPhoto,
                enabled: sensorsEnabled,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.videocam_outlined,
                label: 'Video',
                dense: true,
                onPressed: onVideo,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.mic_none_rounded,
                label: 'Audio',
                dense: true,
                onPressed: onAudio,
                enabled: sensorsEnabled,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.attach_file_rounded,
                label: 'Archivo',
                dense: true,
                onPressed: onFile,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.format_line_spacing_rounded,
                label: 'Densidad',
                dense: true,
                onPressed: onDensity,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.download_rounded,
                label: 'Exportar',
                dense: true,
                onPressed: onExport,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.ios_share_rounded,
                label: 'Compartir',
                dense: true,
                onPressed: onShare,
                variant: AppleButtonVariant.tonal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ========================= Mobile inline editor bar ========================

class _MobileInlineEditorBar extends StatelessWidget {
  const _MobileInlineEditorBar({
    required this.palette,
    required this.density,
    required this.barKey,
    required this.fieldKey,
    required this.isOpen,
    required this.title,
    required this.controller,
    required this.focusNode,
    required this.actions,
    required this.keyboardInset,
    required this.panelHeight,
    required this.canCopyPaste,
    required this.onGpsRow,
    required this.onPrev,
    required this.onNext,
    required this.onCopy,
    required this.onPaste,
    required this.onOverflow,
    required this.onCancel,
    required this.onDone,
  });

  final _SheetPalette palette;
  final _GridDensity density;
  final Key barKey;
  final Key fieldKey;
  final bool isOpen;
  final String title;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_MobileAction> actions;

// inset real de teclado (dp)
  final double keyboardInset;
  final double panelHeight;
  final bool canCopyPaste;
  final VoidCallback? onGpsRow;

  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onOverflow;

  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      const SingleActivator(LogicalKeyboardKey.enter, meta: true): onDone,
      const SingleActivator(LogicalKeyboardKey.enter, control: true): onDone,
      if (onNext != null)
        const SingleActivator(LogicalKeyboardKey.tab): onNext!,
      if (onPrev != null)
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): onPrev!,
    };

// ??? iOS Web: 0 exacto puede hacer que Safari ???no considere??? el input visible.
    final opacity = isOpen ? 1.0 : 0.01;

    final label = title.trim().isEmpty ? 'Editar' : title.trim();
    final metrics = _gridMetricsFor(density);
    final editorFont = (metrics.cellFontSize + 2).clamp(13.0, 17.0);
    final hPad = math.max(10.0, metrics.cellPadding.horizontal / 2);
    final vPad = math.max(10.0, metrics.cellPadding.vertical / 2);
    final editorPadding =
        EdgeInsets.symmetric(horizontal: hPad, vertical: vPad);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          bottom: true,
          child: AbsorbPointer(
            absorbing: !isOpen,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              opacity: opacity,
              child: CallbackShortcuts(
                bindings: bindings,
                child: Container(
                  key: barKey,
                  height: panelHeight,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: palette.appBarBg,
                    border: Border(
                      top: BorderSide(
                          color: palette.borderStrong, width: palette.hairline),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: palette.isLight ? 10 : 14,
                        sigmaY: palette.isLight ? 10 : 14,
                        tileMode: TileMode.decal,
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        decoration: BoxDecoration(
                          color: palette.editorBg
                              .withOpacity(palette.isLight ? 0.96 : 0.70),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: palette.borderStrong,
                              width: palette.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.fgMuted,
                                      fontWeight: FontWeight.w900,
                                      fontSize: metrics.headerFontSize,
                                      height: 1.05,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                                _MobilePanelIconButton(
                                  icon: Icons.chevron_left_rounded,
                                  tooltip: 'Anterior',
                                  onTap: onPrev,
                                  palette: palette,
                                  iconSize: 18,
                                  splashRadius: 16,
                                  padding: const EdgeInsets.all(4),
                                ),
                                _MobilePanelIconButton(
                                  icon: Icons.chevron_right_rounded,
                                  tooltip: 'Siguiente',
                                  onTap: onNext,
                                  palette: palette,
                                  iconSize: 18,
                                  splashRadius: 16,
                                  padding: const EdgeInsets.all(4),
                                ),
                                _MobilePanelIconButton(
                                  icon: Icons.check_rounded,
                                  tooltip: 'Done',
                                  onTap: onDone,
                                  palette: palette,
                                  iconSize: 18,
                                  splashRadius: 16,
                                  padding: const EdgeInsets.all(4),
                                ),
                                _MobilePanelIconButton(
                                  icon: Icons.more_horiz_rounded,
                                  tooltip: 'Acciones',
                                  onTap: onOverflow,
                                  palette: palette,
                                  iconSize: 18,
                                  splashRadius: 16,
                                  padding: const EdgeInsets.all(4),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 46,
                              child: KeyedSubtree(
                                key: fieldKey,
                                child: _MobileEditorField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  palette: palette,
                                  onNext: onNext,
                                  onDone: onDone,
                                  fontSize: editorFont,
                                  contentPadding: editorPadding,
                                ),
                              ),
                            ),
                            // Acciones solo via overflow sheet
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobilePanelIconButton extends StatelessWidget {
  const _MobilePanelIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.palette,
    this.iconSize = 20,
    this.splashRadius = 18,
    this.padding = const EdgeInsets.all(6),
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final _SheetPalette palette;
  final double iconSize;
  final double splashRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled ? palette.fg : palette.fgMuted.withOpacity(0.5);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: fg, size: iconSize),
      padding: padding,
      splashRadius: splashRadius,
    );
  }
}

class _MobileEditorField extends StatelessWidget {
  const _MobileEditorField({
    required this.controller,
    required this.focusNode,
    required this.palette,
    required this.onNext,
    required this.onDone,
    required this.fontSize,
    required this.contentPadding,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _SheetPalette palette;
  final VoidCallback? onNext;
  final VoidCallback onDone;
  final double fontSize;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: false,
      minLines: 1,
      maxLines: 2,
      enabled: true,
      textAlignVertical: TextAlignVertical.center,
      textInputAction:
          onNext == null ? TextInputAction.done : TextInputAction.next,
      keyboardAppearance: palette.isLight ? Brightness.light : Brightness.dark,
      scrollPadding: EdgeInsets.zero,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      style: TextStyle(
        color: palette.fg,
        fontSize: fontSize,
        height: 1.08,
        fontWeight: FontWeight.w800, // ??? nitidez
        letterSpacing: -0.15,
      ),
      cursorColor: palette.accent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
// ??? dark: vidrio visible
        fillColor: palette.mobileInputBg,
        contentPadding: contentPadding,
        hintText: 'Escribir???',
        hintStyle: TextStyle(color: palette.fgMuted),
        border: InputBorder.none,
      ),
      onSubmitted: (_) => onNext == null ? onDone() : onNext!(),
    );
  }
}
