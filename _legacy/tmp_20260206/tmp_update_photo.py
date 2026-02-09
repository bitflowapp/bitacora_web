from pathlib import Path
path = Path('lib/screens/editor_screen.dart')
text = path.read_text(encoding='utf-8')
start = text.find('  Future<void> _processPhotoOutcome(')
if start == -1:
    raise SystemExit('start not found')
end = text.find('  void _addPhotoToCell', start)
if end == -1:
    raise SystemExit('end not found')
new_block = """  Future<void> _processPhotoOutcome(
    PhotoAcquireOutcome outcome,
    CellRef targetRef, {
    bool fromCamera = false,
    int? replaceIndex,
  }) async {
    var currentOutcome = outcome;

    if (fromCamera &&
        _isIosWeb &&
        (outcome.cancelled || outcome.blocked || outcome.isError)) {
      final fallbackOutcome = await _offerGalleryFallback();
      if (fallbackOutcome != null) {
        currentOutcome = fallbackOutcome;
      }
    }

    final cellLabel = _cellLabelForRef(targetRef);
    final label = cellLabel.isEmpty ? targetRef.compactKey : cellLabel;

    if (currentOutcome.cancelled) {
      _updatePhotoFlowStatus(
        'Destino $label \\u00b7 cancelado',
        target: targetRef,
      );
      _clearPhotoFlowStatusSoon();
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.photo,
        ok: false,
        message: 'photo_cancelled',
      );
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'cancelled',
        error: 'cancelled',
      );
      _showActionSnack(
        'Cancelado por el usuario.',
        isError: true,
        icon: Icons.photo_outlined,
      );
      return;
    }
    if (currentOutcome.blocked) {
      final msg = currentOutcome.error ?? 'Bloqueado por el navegador.';
      _updatePhotoFlowStatus(
        'Destino $label \\u00b7 bloqueado',
        target: targetRef,
      );
      _clearPhotoFlowStatusSoon();
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.photo,
        ok: false,
        message: 'photo_blocked $msg',
      );
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'blocked',
        error: msg,
      );
      _showActionSnack(
        msg,
        isError: true,
        icon: Icons.photo_outlined,
      );
      return;
    }
    if (!currentOutcome.ok) {
      final rawMsg = currentOutcome.error ?? 'No se pudo obtener la foto.';
      final lower = rawMsg.toLowerCase();
      final readFail = lower.contains('empty_bytes') ||
          lower.contains('leer la imagen') ||
          lower.contains('leer los bytes');
      final userMsg = readFail ? _kPhotoReadErrorMsg : rawMsg;

      _updatePhotoFlowStatus(
        'Destino $label \\u00b7 ${readFail ? 'error lectura' : 'error foto'}',
        target: targetRef,
      );
      _clearPhotoFlowStatusSoon();
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.photo,
        ok: false,
        message: 'photo_error $rawMsg',
      );
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: readFail ? 'error_bytes' : 'error',
        error: rawMsg,
      );
      _showActionSnack(
        userMsg,
        isError: true,
        icon: Icons.photo_outlined,
      );
      return;
    }

    final result = currentOutcome.result!;
    final fileSize = result.size ?? result.bytes.lengthInBytes;
    final fileType = result.reportedMime ?? result.mime;
    if (result.bytes.isEmpty && fileSize <= 0) {
      _updatePhotoFlowStatus(
        'Destino $label \\u00b7 bytes vacios',
        target: targetRef,
      );
      _clearPhotoFlowStatusSoon();
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.photo,
        ok: false,
        message: 'photo_error empty_bytes',
      );
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'error_bytes',
        error: 'empty_bytes',
      );
      _showActionSnack(
        _kPhotoReadErrorMsg,
        isError: true,
        icon: Icons.photo_outlined,
      );
      return;
    }

    if (!_checkPhotoLimits(targetRef, fileSize, replaceIndex: replaceIndex)) {
      _updatePhotoFlowStatus(
        'Destino $label \\u00b7 limite por celda',
        target: targetRef,
      );
      _clearPhotoFlowStatusSoon();
      return;
    }

    final safeMime = result.mime.trim().isEmpty
        ? 'application/octet-stream'
        : result.mime.trim();

    final sniffedMime = sniffMime(result.bytes, name: result.name);
    final reportedMime = result.mime.trim();
    DiagnosticsLog.I.updatePhotoAttempt(
      stage: 'bytes_ready',
      fileName: result.name,
      sniffedMime: sniffedMime.isNotEmpty ? sniffedMime : null,
      reportedMime: reportedMime.isNotEmpty ? reportedMime : null,
      bytes: result.bytes.lengthInBytes > 0 ? result.bytes.lengthInBytes : null,
      fileSize: fileSize,
      fileType: fileType,
    );
    _updatePhotoFlowStatus(
      'Destino $label \\u00b7 bytes listos (${_formatBytes(fileSize)})',
      target: targetRef,
    );

    bool attached = false;
    Timer? watchdog;

    Future<void> attach({required bool watchdogFired}) async {
      if (attached) return;
      try {
        final attachmentId = _genAttachmentId('ph_');
        final save = await _attachmentStore.saveImage(
          cellRef: targetRef,
          attachmentId: attachmentId,
          bytes: result.bytes,
          originalName: result.name,
          mime: safeMime,
          webFile: result.webFile,
        );
        if (!mounted) return;
        if (save == null || save.storedRef.trim().isEmpty) {
          _updatePhotoFlowStatus(
            'Destino $label \\u00b7 error guardado',
            target: targetRef,
          );
          _showActionSnack('No se pudo guardar la foto. Revisa permisos.',
              isError: true, icon: Icons.photo_outlined);
          return;
        }

        final storedRef = save.storedRef;
        final storageLabel = save.storageLabel;
        if (storageLabel == 'ram') {
          _warnStorageFallbackOnce('foto');
        }

        final previewable = _isPreviewableMime(safeMime, result.name);
        final thumbBytes = previewable
            ? _compressThumb(result.bytes, maxW: 560, maxH: 560, quality: 78)
            : null;

        DiagnosticsLog.I.updatePhotoAttempt(
          stage: 'stored',
          storageMode: storageLabel,
          storageKey: save.storageKey ?? storedRef,
          bytes: fileSize,
        );
        _updatePhotoFlowStatus(
          'Destino $label \\u00b7 guardado (${storageLabel.toUpperCase()})',
          target: targetRef,
        );

        final thumbB64 = (thumbBytes == null || thumbBytes.isEmpty)
            ? ''
            : base64Encode(thumbBytes);

        final fixOutcome =
            await _getGpsFixWithFallback(timeout: const Duration(seconds: 8));
        if (!mounted) return;

        final attachment = PhotoAttachment(
          id: attachmentId,
          filename: result.name,
          mime: safeMime,
          size: fileSize,
          storedRef: storedRef,
          thumbRef: thumbB64,
          addedAt: DateTime.now(),
          lat: fixOutcome.fix?.lat,
          lon: fixOutcome.fix?.lng,
          accuracyM: fixOutcome.fix?.accuracyM,
          isLastKnown: fixOutcome.fix?.source == 'lastKnown',
        );

        if (!_applyPhotoToRef(targetRef, attachment,
            replaceIndex: replaceIndex)) {
          _showActionSnack(
            'La celda destino ya no existe.',
            isError: true,
            icon: Icons.photo_outlined,
          );
          return;
        }

        DiagnosticsLog.I.updatePhotoAttempt(
          stage: 'meta_attached',
          storageMode: storageLabel,
          previewable: previewable,
        );
        DiagnosticsLog.I.updatePhotoAttempt(
          stage: 'ui_refresh',
          storageMode: storageLabel,
          previewable: previewable,
        );
        DiagnosticsLog.I.record(
          type: DiagnosticActionType.photo,
          ok: true,
          message:
              'photo_saved cell=$label name=${result.name} size=$fileSize ref=$storedRef storage=$storageLabel watchdog=$watchdogFired',
        );
        final sizeLabel = _formatBytes(fileSize);
        _showActionSnack(
          'Foto guardada en celda $label ($sizeLabel).',
          isError: false,
          icon: Icons.photo_outlined,
        );
        _updatePhotoFlowStatus(
          'Destino $label \\u00b7 guardada',
          target: targetRef,
        );
        _clearPhotoFlowStatusSoon();
        attached = true;
      } catch (e, st) {
        DiagnosticsLog.I.updatePhotoAttempt(
          stage: 'attach_error',
          error: e.toString(),
          stack: st.toString(),
        );
        _updatePhotoFlowStatus(
          'Destino $label \\u00b7 error adjuntar',
          target: targetRef,
        );
        _showActionSnack('No se pudo guardar la foto. Revisa permisos.',
            isError: true, icon: Icons.photo_outlined);
      }
    }

    watchdog = Timer(const Duration(milliseconds: 1500), () {
      if (attached) return;
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'watchdog_attach',
        error: 'timeout_after_bytes',
      );
      unawaited(attach(watchdogFired: true));
    });

    await attach(watchdogFired: false);
    try {
      watchdog.cancel();
    } catch (_) {}
  }

  bool _checkPhotoLimits(CellRef ref, int incomingBytes,
      {int? replaceIndex}) {
    final current = _cellMeta[ref.key];
    final photos = current?.photos ?? const <PhotoAttachment>[];
    final count = photos.length;
    final totalBytes =
        photos.fold<int>(0, (sum, p) => sum + p.size);

    if (replaceIndex != null) {
      if (replaceIndex < 0 || replaceIndex >= photos.length) {
        return false;
      }
    }

    final baseBytes = (replaceIndex == null)
        ? totalBytes
        : totalBytes - photos[replaceIndex].size;
    final nextBytes = baseBytes + incomingBytes;
    final nextCount = (replaceIndex == null) ? (count + 1) : count;

    if (replaceIndex == null && nextCount > _kMaxPhotosPerCell) {
      _showActionSnack(
        'Limite por celda: max $_kMaxPhotosPerCell fotos.',
        isError: true,
        icon: Icons.photo_outlined,
      );
      return false;
    }
    if (nextBytes > _kMaxPhotosBytesPerCell) {
      final limitLabel = _formatBytes(_kMaxPhotosBytesPerCell);
      _showActionSnack(
        'Limite por celda: max $limitLabel.',
        isError: true,
        icon: Icons.photo_outlined,
      );
      return false;
    }
    return true;
  }

  bool _applyPhotoToRef(CellRef ref, PhotoAttachment attachment,
      {int? replaceIndex}) {
    if (_cellIndexForRef(ref) == null) return false;
    final current = _cellMeta[ref.key];

    if (replaceIndex != null) {
      if (current == null) return false;
      if (replaceIndex < 0 || replaceIndex >= current.photos.length) {
        return false;
      }
      final nextPhotos = List<PhotoAttachment>.from(current.photos);
      final previous = nextPhotos[replaceIndex];
      nextPhotos[replaceIndex] = attachment;
      final next = CellMeta(
        gps: current.gps,
        photos: nextPhotos,
        audios: current.audios,
      );
      _setCellMetaEntryRef(ref, next, markDirty: true);
      _refreshCellAfterSaveRef(ref);
      if (previous.storedRef.trim().isNotEmpty) {
        unawaited(_attachmentStore.delete(previous.storedRef));
      }
      return true;
    }

    final photos = <PhotoAttachment>[
      ...?current?.photos,
      attachment,
    ];
    final next = CellMeta(
      gps: current?.gps,
      photos: photos,
      audios: current?.audios ?? const <AudioAttachment>[],
    );
    _setCellMetaEntryRef(ref, next, markDirty: true);
    _refreshCellAfterSaveRef(ref);
    return true;
  }

"""
text = text[:start] + new_block + text[end:]
path.write_text(text, encoding='utf-8')
print('updated')
