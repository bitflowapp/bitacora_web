import 'package:bitacora_web/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommandAction {
  final String id;
  final String label;
  final String? subtitle;
  final String? shortcut;
  final IconData? icon;
  final VoidCallback onSelected;

  CommandAction({
    required this.id,
    required this.label,
    required this.onSelected,
    this.subtitle,
    this.shortcut,
    this.icon,
  });
}

/// Paleta de comandos con busqueda, flechas y Enter. Cierra con Esc.
Future<void> showCommandPalette(
  BuildContext context, {
  required List<CommandAction> actions,
  String title = 'Acciones',
}) async {
  final queryCtl = TextEditingController();
  final listCtl = ScrollController();

  List<CommandAction> filter(String q) {
    if (q.isEmpty) return actions;
    final s = q.toLowerCase();
    return actions.where((a) {
      final t = a.label.toLowerCase();
      final st = a.subtitle?.toLowerCase() ?? '';
      return t.contains(s) || st.contains(s);
    }).toList(growable: false);
  }

  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'command_palette',
      barrierColor: Colors.black.withValues(alpha: 0.22),
      transitionDuration: AppMotion.modal,
      pageBuilder: (ctx, _, __) {
        var selected = 0;
        var results = filter('');

        void ensureSelectedVisible() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!listCtl.hasClients) return;
            const itemH = 58.0;
            final target = selected * itemH;
            final viewTop = listCtl.offset;
            final viewBot = viewTop + listCtl.position.viewportDimension;
            if (target < viewTop) {
              listCtl.jumpTo(target);
            } else if (target + itemH > viewBot) {
              listCtl.jumpTo(
                (target + itemH) - listCtl.position.viewportDimension,
              );
            }
          });
        }

        void runSelected() {
          if (results.isEmpty) return;
          final action = results[selected.clamp(0, results.length - 1)];
          AppHaptics.light();
          Navigator.of(ctx).pop();
          Future.microtask(action.onSelected);
        }

        return StatefulBuilder(
          builder: (ctx, setState) {
            void move(int delta) {
              if (results.isEmpty) return;
              setState(() {
                selected = (selected + delta).clamp(0, results.length - 1);
              });
              AppHaptics.selection();
              ensureSelectedVisible();
            }

            final theme = Theme.of(ctx);
            final light = theme.brightness == Brightness.light;
            final fg = theme.textTheme.bodyLarge?.color ??
                (light ? const Color(0xFF111111) : Colors.white);
            final selectedBg = fg.withValues(alpha: light ? 0.08 : 0.16);

            return Dialog(
              key: const ValueKey('command_palette_dialog'),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: Focus(
                autofocus: true,
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  final k = event.logicalKey;
                  if (k == LogicalKeyboardKey.arrowUp) {
                    move(-1);
                    return KeyEventResult.handled;
                  }
                  if (k == LogicalKeyboardKey.arrowDown) {
                    move(1);
                    return KeyEventResult.handled;
                  }
                  if (k == LogicalKeyboardKey.enter) {
                    runSelected();
                    return KeyEventResult.handled;
                  }
                  if (k == LogicalKeyboardKey.escape) {
                    Navigator.of(ctx).pop();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 760, maxHeight: 520),
                  child: Material(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const _Kbd('Esc'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                key: const ValueKey('command_palette_search'),
                                controller: queryCtl,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search_rounded),
                                  hintText: 'Escribe para filtrar...',
                                ),
                                onChanged: (q) {
                                  setState(() {
                                    results = filter(q);
                                    selected = 0;
                                  });
                                },
                                onSubmitted: (_) => runSelected(),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 0),
                        Flexible(
                          child: results.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(
                                    child: Text(
                                      'Sin resultados',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  key: const ValueKey(
                                    'command_palette_results',
                                  ),
                                  controller: listCtl,
                                  itemExtent: 58,
                                  itemCount: results.length,
                                  itemBuilder: (c, i) {
                                    final a = results[i];
                                    final sel = i == selected;
                                    return InkWell(
                                      key: ValueKey(
                                        'command_palette_action_${a.id}',
                                      ),
                                      onTap: () {
                                        setState(() => selected = i);
                                        runSelected();
                                      },
                                      child: AnimatedContainer(
                                        duration: AppMotion.micro,
                                        curve: AppMotion.standardOut,
                                        decoration: BoxDecoration(
                                          color: sel
                                              ? selectedBg
                                              : Colors.transparent,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              a.icon ?? Icons.bolt_outlined,
                                              size: 20,
                                              color: sel
                                                  ? fg
                                                  : theme.iconTheme.color,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    a.label,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1.1,
                                                    ),
                                                  ),
                                                  if ((a.subtitle ?? '')
                                                      .isNotEmpty)
                                                    Text(
                                                      a.subtitle!,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: theme
                                                          .textTheme.bodySmall,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (a.shortcut != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                child: _Kbd(a.shortcut!),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (ctx, animation, _, child) {
        return AppMotion.modalTransition(
          context: ctx,
          animation: animation,
          child: child,
        );
      },
    );
  } finally {
    await Future<void>.delayed(AppMotion.modal);
    queryCtl.dispose();
    listCtl.dispose();
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: light ? const Color(0xFFF7F7F9) : const Color(0xFF141922),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
