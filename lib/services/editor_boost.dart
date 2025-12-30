// lib/services/editor_boost.dart
// EditorBoost: hotkeys de edición + ajuste automático de columnas al viewport.
// Pensado para teclado en PC (Windows/macOS/Linux) y móviles/tablets con teclado
// (Android / iOS / iPadOS).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callbacks mínimos que el Editor expone al booster.
class EditorBindings {
  EditorBindings({
    required this.rowCount,
    required this.colCount,
    required this.getFocus, // retorna (r,c) actual
    required this.setFocus, // mover foco a (r,c)
    required this.startEdit, // activar edición en (r,c)
    required this.writeCell, // escribir valor directo (sin requerir modo edición)
    required this.readCell, // leer valor de (r,c)
    required this.newRow, // insertar nueva fila al final
    required this.deleteRow, // borrar fila actual
    required this.undo,
    required this.redo,
    required this.autoFitColumn, // autofit de una columna
    required this.clearCell, // limpiar celda actual
  });

  final int Function() rowCount;
  final int Function() colCount;
  final ({int r, int c}) Function() getFocus;
  final void Function(int r, int c) setFocus;
  final void Function(int r, int c) startEdit;
  final void Function(int r, int c, String value) writeCell;
  final String Function(int r, int c) readCell;
  final VoidCallback newRow;
  final VoidCallback deleteRow;
  final VoidCallback undo;
  final VoidCallback redo;
  final void Function(int colIndex) autoFitColumn;
  final void Function(int r, int c) clearCell;
}

/// Widget que inyecta atajos sin romper los que ya tenés.
class EditorBoost extends StatelessWidget {
  const EditorBoost({
    super.key,
    required this.bindings,
    required this.child,
  });

  final EditorBindings bindings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mapShortcuts = <LogicalKeySet, Intent>{
      // ---------------- Edición rápida ----------------

      // F2 = editar celda actual
      LogicalKeySet(LogicalKeyboardKey.f2): const _EditIntent(),

      // Supr = limpiar celda actual
      LogicalKeySet(LogicalKeyboardKey.delete): const _ClearIntent(),

      // Ctrl+Enter / Cmd+Enter = nueva fila debajo y foco
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.enter,
      ): const _NewRowBelowIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.enter,
      ): const _NewRowBelowIntent(),

      // Ctrl+N / Cmd+N = nueva fila al final y foco en la nueva
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyN,
      ): const _NewRowBelowIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyN,
      ): const _NewRowBelowIntent(),

      // Ctrl+Backspace / Cmd+Backspace = borrar fila actual
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.backspace,
      ): const _DeleteRowIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.backspace,
      ): const _DeleteRowIntent(),

      // ---------------- Clipboard (PC / Mac / tablet con teclado) ----------------

      // Copiar
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyC,
      ): const _CopyIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyC,
      ): const _CopyIntent(),

      // Cortar
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyX,
      ): const _CutIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyX,
      ): const _CutIntent(),

      // Pegar
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyV,
      ): const _PasteIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyV,
      ): const _PasteIntent(),

      // ---------------- Navegación extendida ----------------

      // Ctrl+← / Cmd+← = ir a primera columna de la fila
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.arrowLeft,
      ): const _MoveStartColIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.arrowLeft,
      ): const _MoveStartColIntent(),

      // Ctrl+→ / Cmd+→ = ir a última columna de la fila
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.arrowRight,
      ): const _MoveEndColIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.arrowRight,
      ): const _MoveEndColIntent(),

      // Ctrl+↑ / Cmd+↑ = ir a primera fila
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.arrowUp,
      ): const _MoveStartRowIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.arrowUp,
      ): const _MoveStartRowIntent(),

      // Ctrl+↓ / Cmd+↓ = ir a última fila
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.arrowDown,
      ): const _MoveEndRowIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.arrowDown,
      ): const _MoveEndRowIntent(),

      // PageUp / PageDown = saltos de 10 filas
      LogicalKeySet(LogicalKeyboardKey.pageUp): const _PageUpIntent(),
      LogicalKeySet(LogicalKeyboardKey.pageDown): const _PageDownIntent(),

      // Home / End = principio / fin de fila
      LogicalKeySet(LogicalKeyboardKey.home): const _RowHomeIntent(),
      LogicalKeySet(LogicalKeyboardKey.end): const _RowEndIntent(),

      // Ctrl+Home / Cmd+Home = primera celda (0,0)
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.home,
      ): const _TableHomeIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.home,
      ): const _TableHomeIntent(),

      // Ctrl+End / Cmd+End = última celda (última fila / última col)
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.end,
      ): const _TableEndIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.end,
      ): const _TableEndIntent(),

      // ---------------- Undo / Redo (PC + Mac + iPad) ----------------

      // Ctrl+Z / Cmd+Z = undo
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyZ,
      ): const _UndoIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyZ,
      ): const _UndoIntent(),

      // Ctrl+Y / Cmd+Y = redo
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyY,
      ): const _RedoIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyY,
      ): const _RedoIntent(),

      // Ctrl+Shift+Z / Cmd+Shift+Z = redo
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.keyZ,
      ): const _RedoIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.keyZ,
      ): const _RedoIntent(),

      // ---------------- Utilidades ----------------

      // Ctrl+F / Cmd+F = autofit de columna actual
      LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyF,
      ): const _AutoFitIntent(),
      LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyF,
      ): const _AutoFitIntent(),
    };

    final mapActions = <Type, Action<Intent>>{
      // -------- Edición básica --------
      _EditIntent: CallbackAction<_EditIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        bindings.startEdit(f.r, f.c);
        return null;
      }),
      _ClearIntent: CallbackAction<_ClearIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        bindings.clearCell(f.r, f.c);
        return null;
      }),
      _NewRowBelowIntent:
      CallbackAction<_NewRowBelowIntent>(onInvoke: (_) {
        if (bindings.colCount() <= 0) return null;

        // Si no hay filas todavía, simplemente creamos una y enfocamos la 0.
        if (bindings.rowCount() <= 0) {
          bindings.newRow();
          if (bindings.rowCount() > 0) {
            bindings.setFocus(0, 0);
          }
          return null;
        }

        final f = bindings.getFocus();
        bindings.newRow();
        final total = bindings.rowCount();
        if (total <= 0) return null;
        final r = (f.r + 1).clamp(0, total - 1);
        final c = f.c.clamp(0, bindings.colCount() - 1);
        bindings.setFocus(r, c);
        return null;
      }),
      _DeleteRowIntent: CallbackAction<_DeleteRowIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final totalBefore = bindings.rowCount();
        if (totalBefore <= 0) return null;

        final f = bindings.getFocus();
        final currentRow = f.r.clamp(0, totalBefore - 1);

        bindings.deleteRow();

        final totalAfter = bindings.rowCount();
        if (totalAfter <= 0) return null;

        // Reubicar foco en la fila anterior (o 0 si borramos la primera)
        final nextRow = (currentRow - 1).clamp(0, totalAfter - 1);
        final col = f.c.clamp(0, bindings.colCount() - 1);
        bindings.setFocus(nextRow, col);
        return null;
      }),

      // -------- Clipboard --------
      _CopyIntent: CallbackAction<_CopyIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final txt = bindings.readCell(f.r, f.c);
        Clipboard.setData(ClipboardData(text: txt));
        return null;
      }),
      _CutIntent: CallbackAction<_CutIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final txt = bindings.readCell(f.r, f.c);
        Clipboard.setData(ClipboardData(text: txt));
        bindings.writeCell(f.r, f.c, '');
        return null;
      }),
      _PasteIntent: CallbackAction<_PasteIntent>(onInvoke: (_) async {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final data = await Clipboard.getData('text/plain');
        final txt = (data?.text ?? '').replaceAll('\r\n', '\n');

        // Si viene una sola celda, pegamos directo.
        if (!txt.contains('\n') && !txt.contains('\t')) {
          bindings.writeCell(f.r, f.c, txt);
          return null;
        }

        // Soporte básico multi-celda: distribuye por filas/columnas.
        final rows = txt.split('\n').map((l) => l.split('\t')).toList();
        final maxRows = bindings.rowCount();
        final maxCols = bindings.colCount();

        int rr = f.r;
        for (final line in rows) {
          int cc = f.c;
          for (final cell in line) {
            if (rr < maxRows && cc < maxCols) {
              bindings.writeCell(rr, cc, cell);
            }
            cc++;
          }
          rr++;
        }
        return null;
      }),

      // -------- Navegación extendida --------
      _MoveStartColIntent:
      CallbackAction<_MoveStartColIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final row = f.r.clamp(0, bindings.rowCount() - 1);
        bindings.setFocus(row, 0);
        return null;
      }),
      _MoveEndColIntent: CallbackAction<_MoveEndColIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final row = f.r.clamp(0, bindings.rowCount() - 1);
        final lastCol = bindings.colCount() - 1;
        if (lastCol < 0) return null;
        bindings.setFocus(row, lastCol);
        return null;
      }),
      _MoveStartRowIntent:
      CallbackAction<_MoveStartRowIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final col = f.c.clamp(0, bindings.colCount() - 1);
        bindings.setFocus(0, col);
        return null;
      }),
      _MoveEndRowIntent: CallbackAction<_MoveEndRowIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final lastRow = bindings.rowCount() - 1;
        if (lastRow < 0) return null;
        final col = f.c.clamp(0, bindings.colCount() - 1);
        bindings.setFocus(lastRow, col);
        return null;
      }),
      _PageUpIntent: CallbackAction<_PageUpIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final total = bindings.rowCount();
        final r = (f.r - 10).clamp(0, total - 1);
        final c = f.c.clamp(0, bindings.colCount() - 1);
        bindings.setFocus(r, c);
        return null;
      }),
      _PageDownIntent: CallbackAction<_PageDownIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final total = bindings.rowCount();
        final r = (f.r + 10).clamp(0, total - 1);
        final c = f.c.clamp(0, bindings.colCount() - 1);
        bindings.setFocus(r, c);
        return null;
      }),
      _RowHomeIntent: CallbackAction<_RowHomeIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final row = f.r.clamp(0, bindings.rowCount() - 1);
        bindings.setFocus(row, 0);
        return null;
      }),
      _RowEndIntent: CallbackAction<_RowEndIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final row = f.r.clamp(0, bindings.rowCount() - 1);
        final lastCol = bindings.colCount() - 1;
        if (lastCol < 0) return null;
        bindings.setFocus(row, lastCol);
        return null;
      }),
      _TableHomeIntent: CallbackAction<_TableHomeIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        bindings.setFocus(0, 0);
        return null;
      }),
      _TableEndIntent: CallbackAction<_TableEndIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final lastRow = bindings.rowCount() - 1;
        final lastCol = bindings.colCount() - 1;
        if (lastRow < 0 || lastCol < 0) return null;
        bindings.setFocus(lastRow, lastCol);
        return null;
      }),

      // -------- Undo / Redo --------
      _UndoIntent: CallbackAction<_UndoIntent>(onInvoke: (_) {
        bindings.undo();
        return null;
      }),
      _RedoIntent: CallbackAction<_RedoIntent>(onInvoke: (_) {
        bindings.redo();
        return null;
      }),

      // -------- Autofit --------
      _AutoFitIntent: CallbackAction<_AutoFitIntent>(onInvoke: (_) {
        if (!_hasGrid(bindings)) return null;
        final f = bindings.getFocus();
        final cols = bindings.colCount();
        if (cols <= 0) return null;
        final col = f.c.clamp(0, cols - 1);
        bindings.autoFitColumn(col);
        return null;
      }),
    };

    return Shortcuts(
      shortcuts: mapShortcuts,
      child: Actions(
        actions: mapActions,
        child: FocusTraversalGroup(child: child),
      ),
    );
  }
}

/// True si hay al menos una celda en la grilla.
bool _hasGrid(EditorBindings b) =>
    b.rowCount() > 0 && b.colCount() > 0;

/// Distribuye ancho extra para que las columnas llenen el viewport.
/// Retorna una nueva lista con los anchos ajustados.
List<double> fitColumnsToViewport({
  required List<double> widths,
  required double viewportWidth,
  required double indexColumnWidth,
  required double minColWidth,
  required double maxColWidth,
}) {
  // Sin columnas o viewport indefinido: no tocamos nada.
  if (widths.isEmpty) return widths;
  if (!viewportWidth.isFinite || viewportWidth <= 0) return widths;

  final usable =
  (viewportWidth - indexColumnWidth).clamp(0, double.infinity);
  final sum = widths.fold<double>(0, (a, b) => a + b);
  if (sum >= usable) return widths;

  final extra = usable - sum;
  final per = extra / widths.length;

  return [
    for (final w in widths)
      (w + per).clamp(minColWidth, maxColWidth).toDouble(),
  ];
}

/// Widget que llama a `onWidths` cuando el viewport cambia, para estirar columnas.
class ViewportFiller extends StatefulWidget {
  const ViewportFiller({
    super.key,
    required this.indexColumnWidth,
    required this.minColWidth,
    required this.maxColWidth,
    required this.getWidths,
    required this.onWidths,
    required this.child,
  });

  final double indexColumnWidth;
  final double minColWidth;
  final double maxColWidth;
  final List<double> Function() getWidths;
  final void Function(List<double> next) onWidths;
  final Widget child;

  @override
  State<ViewportFiller> createState() => _ViewportFillerState();
}

class _ViewportFillerState extends State<ViewportFiller> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        final viewportWidth = box.maxWidth;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          final current = widget.getWidths();
          final next = fitColumnsToViewport(
            widths: current,
            viewportWidth: viewportWidth,
            indexColumnWidth: widget.indexColumnWidth,
            minColWidth: widget.minColWidth,
            maxColWidth: widget.maxColWidth,
          );

          bool changed = false;
          if (next.length == current.length) {
            for (int i = 0; i < next.length; i++) {
              if ((next[i] - current[i]).abs() > 0.5) {
                changed = true;
                break;
              }
            }
          } else {
            changed = true;
          }

          if (changed && mounted) {
            widget.onWidths(next);
          }
        });

        return widget.child;
      },
    );
  }
}

// ---- Intents internos ----
class _EditIntent extends Intent {
  const _EditIntent();
}

class _ClearIntent extends Intent {
  const _ClearIntent();
}

class _CopyIntent extends Intent {
  const _CopyIntent();
}

class _CutIntent extends Intent {
  const _CutIntent();
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

class _MoveStartColIntent extends Intent {
  const _MoveStartColIntent();
}

class _MoveEndColIntent extends Intent {
  const _MoveEndColIntent();
}

class _MoveStartRowIntent extends Intent {
  const _MoveStartRowIntent();
}

class _MoveEndRowIntent extends Intent {
  const _MoveEndRowIntent();
}

class _PageUpIntent extends Intent {
  const _PageUpIntent();
}

class _PageDownIntent extends Intent {
  const _PageDownIntent();
}

class _RowHomeIntent extends Intent {
  const _RowHomeIntent();
}

class _RowEndIntent extends Intent {
  const _RowEndIntent();
}

class _TableHomeIntent extends Intent {
  const _TableHomeIntent();
}

class _TableEndIntent extends Intent {
  const _TableEndIntent();
}

class _NewRowBelowIntent extends Intent {
  const _NewRowBelowIntent();
}

class _DeleteRowIntent extends Intent {
  const _DeleteRowIntent();
}

class _AutoFitIntent extends Intent {
  const _AutoFitIntent();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}
