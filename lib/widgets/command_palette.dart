// lib/widgets/command_palette.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommandAction {
  final String id;
  final String label;
  final String? subtitle;
  final String? shortcut; // Ej: "Ctrl+N"
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

/// Paleta de comandos con búsqueda, ↑/↓ y Enter. Cierra con Esc.
/// Llamar desde AppBar o atajo global (Ctrl+K / Ctrl+/).
Future<void> showCommandPalette(
  BuildContext context, {
  required List<CommandAction> actions,
  String title = 'Acciones',
}) async {
  final queryCtl = TextEditingController();
  final focusNode = FocusNode();

  List<CommandAction> filter(String q) {
    if (q.isEmpty) return actions;
    final s = q.toLowerCase();
    return actions.where((a) {
      final t = a.label.toLowerCase();
      final st = a.subtitle?.toLowerCase() ?? '';
      return t.contains(s) || st.contains(s);
    }).toList(growable: false);
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final listCtl = ScrollController();
      int selected = 0;
      List<CommandAction> results = filter('');

      void ensureSelectedVisible() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!listCtl.hasClients) return;
          const itemH = 56.0;
          final target = selected * itemH;
          final viewTop = listCtl.offset;
          final viewBot = viewTop + listCtl.position.viewportDimension;
          if (target < viewTop) {
            listCtl.jumpTo(target);
          } else if (target + itemH > viewBot) {
            listCtl
                .jumpTo((target + itemH) - listCtl.position.viewportDimension);
          }
        });
      }

      void runSelected() {
        if (results.isEmpty) return;
        final action = results[selected.clamp(0, results.length - 1)];
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
            ensureSelectedVisible();
          }

          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: RawKeyboardListener(
              focusNode: FocusNode()..requestFocus(),
              onKey: (RawKeyEvent e) {
                if (e is! RawKeyDownEvent) return;
                final k = e.logicalKey;
                if (k == LogicalKeyboardKey.arrowUp) {
                  move(-1);
                } else if (k == LogicalKeyboardKey.arrowDown) {
                  move(1);
                } else if (k == LogicalKeyboardKey.enter) {
                  runSelected();
                } else if (k == LogicalKeyboardKey.escape) {
                  Navigator.of(ctx).pop();
                }
              },
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 720, maxHeight: 480),
                child: Material(
                  color: Theme.of(ctx).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header + búsqueda
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
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const _Kbd('Esc'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: queryCtl,
                              focusNode: focusNode,
                              autofocus: true,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Escribe para filtrar…',
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
                      // Resultados
                      Flexible(
                        child: results.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'Sin resultados',
                                    style: Theme.of(ctx).textTheme.bodyMedium,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: listCtl,
                                itemExtent: 56,
                                itemCount: results.length,
                                itemBuilder: (c, i) {
                                  final a = results[i];
                                  final sel = i == selected;
                                  return InkWell(
                                    onTap: () {
                                      setState(() => selected = i);
                                      runSelected();
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? Theme.of(ctx)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.08)
                                            : Colors.transparent,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Row(
                                        children: [
                                          Icon(
                                            a.icon ?? Icons.bolt_outlined,
                                            size: 20,
                                            color: sel
                                                ? Theme.of(ctx)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(ctx).iconTheme.color,
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
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if ((a.subtitle ?? '')
                                                    .isNotEmpty)
                                                  Text(
                                                    a.subtitle!,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(ctx)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (a.shortcut != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8),
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
  );

  queryCtl.dispose();
  focusNode.dispose();
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
