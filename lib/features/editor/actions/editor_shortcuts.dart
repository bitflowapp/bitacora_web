part of '../editor_screen.dart';

extension _EditorShortcuts on _EditorScreenState {
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_gpsPickingTarget) {
        _cancelGpsPick();
        return KeyEventResult.handled;
      }
      if (_mobileEditorOpen) {
        _cancelMobileEdit();
        return KeyEventResult.handled;
      }
      if (_cellEditorEntry != null) {
        _removeCellEditor();
        return KeyEventResult.handled;
      }
    }

    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.widget is EditableText) {
      return KeyEventResult.ignored;
    }

    if (_cellEditorEntry != null || _mobileEditorOpen) {
      return KeyEventResult.ignored;
    }

    final isCmd = HardwareKeyboard.instance.isMetaPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isMod = isCmd || isCtrl;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSel(dRow: 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSel(dRow: -1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveSel(dCol: 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveSel(dCol: -1);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _moveSelectionFast(forward: !isShift, vertical: false);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _moveSelectionFast(forward: !isShift, vertical: true);
      return KeyEventResult.handled;
    }

    if (isMod && isShift && event.logicalKey == LogicalKeyboardKey.keyZ) {
      unawaited(_toggleZenMode());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyZ) {
      _undoOnce();
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyY) {
      _redoOnce();
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyC) {
      unawaited(_copySelectionToClipboard());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyV) {
      unawaited(_pasteFromClipboard());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyS) {
      unawaited(_saveLocalNow());
      return KeyEventResult.handled;
    }

    if (isMod && isShift && event.logicalKey == LogicalKeyboardKey.keyF) {
      unawaited(_openSearchEverywhereDialog());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyF) {
      unawaited(_openSearchDialog());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyJ) {
      unawaited(_openJumpToDialog());
      return KeyEventResult.handled;
    }

    if (isMod && isShift && event.logicalKey == LogicalKeyboardKey.keyM) {
      unawaited(_openRowFormMode(rowIndex: _selRow, createNew: false));
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyN) {
      _insertRow(_rows.length);
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyE) {
      if (isAlt) {
        unawaited(_exportZipBundle(share: false));
        return KeyEventResult.handled;
      }
      if (isShift) {
        unawaited(_exportXlsxOnly());
        return KeyEventResult.handled;
      }
      if (_selCol >= 0 && _selCol < _headers.length - 1) {
        _setColumnPresentationForIndex(
          _selCol,
          textAlign: _GridTextAlignX.center,
          verticalAlign: _GridTextAlignY.middle,
        );
      }
      return KeyEventResult.handled;
    }

    if (isMod && isAlt && event.logicalKey == LogicalKeyboardKey.keyC) {
      if (_selCol >= 0 && _selCol < _headers.length - 1) {
        _setColumnPresentationForIndex(
          _selCol,
          textAlign: _GridTextAlignX.center,
          verticalAlign: _GridTextAlignY.middle,
        );
      }
      return KeyEventResult.handled;
    }

    if (isMod && isShift && event.logicalKey == LogicalKeyboardKey.keyI) {
      unawaited(_openImportPackageDialog());
      return KeyEventResult.handled;
    }

    if (isMod && isShift && event.logicalKey == LogicalKeyboardKey.keyB) {
      unawaited(_promptBatchApplyValue());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyD) {
      unawaited(_promptFillDown(context, _selRow, _selCol));
      return KeyEventResult.handled;
    }

    if (isMod && isShift && event.logicalKey == LogicalKeyboardKey.keyL) {
      if (_selCol >= 0 && _selCol < _headers.length - 1) {
        final colId = _colIds[_selCol];
        final currentWrap = (_columnPrefsById[colId]?.wrapLines ?? 1).clamp(
          1,
          3,
        );
        _setColumnPresentationForIndex(
          _selCol,
          wrapLines: currentWrap == 1 ? 2 : (currentWrap == 2 ? 3 : 1),
        );
      }
      return KeyEventResult.handled;
    }

    if (isMod && isAlt && event.logicalKey == LogicalKeyboardKey.keyL) {
      unawaited(_openOfflineQueueDialog());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyK) {
      unawaited(_openCommandPalette());
      return KeyEventResult.handled;
    }

    if (isMod && isShift && event.logicalKey == LogicalKeyboardKey.keyR) {
      unawaited(_openFlowBotSheet());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyG) {
      unawaited(_requestGpsForCell(_selRow, _selCol, forceWriteText: true));
      return KeyEventResult.handled;
    }

    if (isMod && isShift && event.logicalKey == LogicalKeyboardKey.keyA) {
      if (_audioRecording) {
        unawaited(_stopAudioRecording());
      } else {
        unawaited(_startAudioRecordingForCell(_selRow, _selCol));
      }
      return KeyEventResult.handled;
    }

    if (isMod && isShift && event.logicalKey == LogicalKeyboardKey.keyP) {
      unawaited(
        _exportPdf(
          includeAttachments: true,
          share: false,
        ),
      );
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyP) {
      unawaited(_startPhotoFlowForCell(_selRow, _selCol));
      return KeyEventResult.handled;
    }

    if (!isMod && !isAlt) {
      if (event.logicalKey == LogicalKeyboardKey.keyG) {
        unawaited(_requestGpsForCell(_selRow, _selCol, forceWriteText: true));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyP) {
        unawaited(_startPhotoFlowForCell(_selRow, _selCol));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyA) {
        if (_audioRecording) {
          unawaited(_stopAudioRecording());
        } else {
          unawaited(_startAudioRecordingForCell(_selRow, _selCol));
        }
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _setCell(_selRow, _selCol, '');
      return KeyEventResult.handled;
    }

    final printableChar = _extractPrintableChar(event);
    if (printableChar != null &&
        _selRow >= 0 &&
        _selCol >= 0 &&
        _selRow < _rows.length &&
        _selCol < _headers.length) {
      _beginEditCell(
        context,
        _palette(context),
        _selRow,
        _selCol,
        340,
        initialOverride: printableChar,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String? _extractPrintableChar(KeyDownEvent event) {
    final char = event.character;
    if (char == null || char.isEmpty) return null;
    if (char.codeUnits.any((unit) => unit < 32)) return null;

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return null;
    }

    return char;
  }
}
