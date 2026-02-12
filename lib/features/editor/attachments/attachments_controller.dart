part of '../editor_screen.dart';

extension _EditorAttachments on _EditorScreenState {
  Future<void> _startPhotoFlowForCell(int r, int c) async {
    if (_rows.isEmpty || _headers.isEmpty) return;
    final target = await _ensurePhotoTargetCell(r, c);
    if (target == null) return;
    final ref = _cellRefAt(target.row, target.col);
    if (ref == null) return;

    if (_guardInAppBrowser(DiagnosticActionType.photo)) return;

    _photoFlowActive = true;
    _updatePhotoFlowStatus(
      'Destino ${_cellLabelForRef(ref)} · esperando seleccion',
      target: ref,
    );

    final picked = await _showPhotoSourcePicker();
    if (!mounted) return;
    if (picked == null) {
      _photoFlowActive = false;
      _updatePhotoFlowStatus(
        'Destino ${_cellLabelForRef(ref)} · cancelado',
        target: ref,
      );
      _clearPhotoFlowStatusSoon();
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'cancelled',
        error: 'sheet_closed',
      );
      return;
    }

    await _processPhotoOutcome(
      picked.outcome,
      ref,
      fromCamera: picked.fromCamera,
    );
    _photoFlowActive = false;
  }

  Future<void> _pickMultiplePhotosForCell(int r, int c) async {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    final ref = _cellRefAt(r, c);
    if (ref == null) return;

    if (_guardInAppBrowser(DiagnosticActionType.photo)) return;

    _photoFlowActive = true;
    _updatePhotoFlowStatus(
      'Destino ${_cellLabelForRef(ref)} · seleccion multiple',
      target: ref,
    );

    final batch = await PhotoAcquireService.I.pickMultipleFromGallery();
    if (!mounted) return;

    if (batch.cancelled) {
      _photoFlowActive = false;
      _updatePhotoFlowStatus(
        'Destino ${_cellLabelForRef(ref)} · cancelado',
        target: ref,
      );
      _clearPhotoFlowStatusSoon();
      return;
    }
    if (!batch.ok) {
      _photoFlowActive = false;
      _updatePhotoFlowStatus(
        'Destino ${_cellLabelForRef(ref)} · error',
        target: ref,
      );
      _clearPhotoFlowStatusSoon();
      _reportFlowErrorMessage(
        batch.error ?? 'photo_batch_pick_failed',
        flow: AppErrorFlow.attachmentPermission,
        operation: 'photo_batch_pick',
        fallbackMessage: 'No se pudieron cargar las fotos seleccionadas.',
        icon: Icons.photo_outlined,
        diagnosticType: DiagnosticActionType.photo,
      );
      return;
    }

    final results = batch.results;
    for (int i = 0; i < results.length; i++) {
      _updatePhotoFlowStatus(
        'Destino ${_cellLabelForRef(ref)} · procesando ${i + 1}/${results.length}',
        target: ref,
      );
      await _processPhotoOutcome(
        PhotoAcquireOutcome.success(results[i]),
        ref,
        fromCamera: false,
      );
      if (!mounted) return;
    }

    _photoFlowActive = false;
    _updatePhotoFlowStatus(
      'Destino ${_cellLabelForRef(ref)} · ${results.length} foto(s) agregada(s)',
      target: ref,
    );
    _clearPhotoFlowStatusSoon();
  }

  String _genAttachmentId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = math.Random().nextInt(_kStableIdRandomMaxExclusive);
    return '$prefix$now$rand';
  }

  static const String _causeStorageBlocked = 'storage_blocked';
  static const String _causeDecodeUnsupported = 'decode_unsupported';
  static const String _causeMicDenied = 'mic_denied';
  static const String _causeMicUnsupported = 'mic_unsupported';
  static const bool _kFlutterTestEnv = bool.fromEnvironment('FLUTTER_TEST');

  bool get _isWidgetTestRuntime {
    if (_kFlutterTestEnv) return true;
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding');
  }

  bool _isHeicLike({required String mime, required String name}) {
    final m = mime.toLowerCase();
    final n = name.toLowerCase();
    if (m.contains('image/heic') || m.contains('image/heif')) return true;
    return n.endsWith('.heic') || n.endsWith('.heif');
  }

  bool _decodeLikelyUnsupported({
    required String rawMessage,
    String mime = '',
    String name = '',
  }) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('decode') ||
        lower.contains('empty_bytes') ||
        lower.contains('leer la imagen') ||
        lower.contains('leer los bytes') ||
        lower.contains('heic') ||
        lower.contains('heif')) {
      return true;
    }
    return _isHeicLike(mime: mime, name: name);
  }

  String _audioErrorCode(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('mic_denied') ||
        lower.contains('notallowed') ||
        lower.contains('permission') ||
        lower.contains('denied')) {
      return _causeMicDenied;
    }
    if (lower.contains('mic_unsupported') ||
        lower.contains('notsupported') ||
        lower.contains('not supported') ||
        lower.contains('media_recorder') ||
        lower.contains('media devices')) {
      return _causeMicUnsupported;
    }
    return '';
  }

  String _photoMessageForCause(String cause) {
    switch (cause) {
      case _causeStorageBlocked:
        return 'No se pudo guardar la foto. Causa: storage_blocked.';
      case _causeDecodeUnsupported:
        return 'No se pudo procesar la foto. Causa: decode_unsupported.';
      default:
        final c = cause.trim().isEmpty ? 'unknown' : cause.trim();
        return 'No se pudo guardar la foto. Causa: $c.';
    }
  }

  String _audioMessageForCause(String cause) {
    switch (cause) {
      case _causeMicDenied:
        return 'No se pudo iniciar la grabacion. Causa: mic_denied.';
      case _causeMicUnsupported:
        return 'Grabacion no disponible en este navegador. Causa: mic_unsupported.';
      case _causeStorageBlocked:
        return 'No se pudo guardar el audio. Causa: storage_blocked.';
      default:
        final c = cause.trim().isEmpty ? 'unknown' : cause.trim();
        return 'No se pudo iniciar la grabacion de audio. Causa: $c.';
    }
  }

  Future<void> _refreshAttachmentCapabilitiesIfWeb() async {
    if (!kIsWeb) return;
    try {
      _lastAttachmentCapabilities = await _webAttachmentCapabilities.snapshot();
      if (_lastAttachmentCapabilities?.privateModeLikely == true) {
        _warnStorageFallbackOnce(
          'modo temporal (${_lastAttachmentCapabilities?.privateModeReason ?? 'private'})',
        );
      }
    } catch (_) {}
  }

  String _legacyCauseFromPipelineReason(String reasonCode) {
    switch (reasonCode) {
      case 'decoder_failed':
        return _causeDecodeUnsupported;
      case 'mic_denied':
        return _causeMicDenied;
      case 'mic_unsupported':
        return _causeMicUnsupported;
      case 'storage_blocked':
      case 'quota':
        return _causeStorageBlocked;
      default:
        return reasonCode.trim().isEmpty ? 'unknown' : reasonCode.trim();
    }
  }

  String _attachmentMessageForFailure(
    AttachmentClassifiedError failure, {
    required AttachmentKind kind,
  }) {
    final reason = _legacyCauseFromPipelineReason(failure.code);
    switch (kind) {
      case AttachmentKind.photo:
        return _photoMessageForCause(reason);
      case AttachmentKind.audio:
        return _audioMessageForCause(reason);
      case AttachmentKind.video:
        return 'No se pudo adjuntar el video. Causa: $reason.';
      case AttachmentKind.doc:
        return 'No se pudo adjuntar el archivo. Causa: $reason.';
      case AttachmentKind.location:
        return 'No se pudo guardar la ubicacion. Causa: $reason.';
    }
  }

  String _buildAttachmentDiagnostic({
    required String cause,
    required String operation,
    required DiagnosticActionType type,
    String? operationId,
    String? step,
    String? mime,
    int? size,
    String? fileName,
    Object? error,
    StackTrace? stackTrace,
    Map<String, String>? extra,
  }) {
    final photoAttempt = DiagnosticsLog.I.lastPhotoAttempt.value;
    final supportUa = _lastAudioSupport?.userAgent ?? '';
    final ua = supportUa.trim().isNotEmpty
        ? supportUa.trim()
        : (photoAttempt?.ua?.trim().isNotEmpty == true
            ? photoAttempt!.ua!.trim()
            : 'n/a');
    final lines = <String>[
      'type=${type.name}',
      'cause=$cause',
      'operation=$operation',
      if ((operationId ?? '').trim().isNotEmpty)
        'operation_id=${operationId!.trim()}',
      if ((step ?? '').trim().isNotEmpty) 'step=${step!.trim()}',
      'sheet=${widget.sheetId}',
      'ua=$ua',
      'mime=${(mime ?? '').trim().isEmpty ? 'n/a' : mime!.trim()}',
      'size=${size ?? 0}',
      'file=${(fileName ?? '').trim().isEmpty ? 'n/a' : fileName!.trim()}',
    ];
    final caps = _lastAttachmentCapabilities;
    if (caps != null) {
      lines.add('caps=${jsonEncode(caps.toJson())}');
    }
    final counters = DiagnosticsLog.I.attachmentReasonCounters.value;
    if (counters.isNotEmpty) {
      lines.add('reason_counters=${jsonEncode(counters)}');
    }
    if (extra != null) {
      for (final entry in extra.entries) {
        final key = entry.key.trim();
        if (key.isEmpty) continue;
        lines.add('$key=${entry.value}');
      }
    }
    final errText = error?.toString().trim() ?? '';
    if (errText.isNotEmpty) lines.add('error=$errText');
    final stackText = stackTrace?.toString().trim() ?? '';
    if (stackText.isNotEmpty) lines.add('stack=$stackText');
    return lines.join('\n');
  }

  String _photoStoredRefFrom(StoredPhoto stored) {
    final path = stored.path.trim();
    if (path.isNotEmpty) {
      if (path.startsWith('key:') || path.startsWith('mem:')) {
        return path;
      }
      return 'file:$path';
    }
    if (stored.dataB64.trim().isNotEmpty) {
      return 'b64:${stored.dataB64}';
    }
    return '';
  }

  String _photoPathFromRef(String storedRef) {
    final raw = storedRef.trim();
    if (raw.startsWith('key:')) return raw;
    if (raw.startsWith('mem:')) return raw;
    if (raw.startsWith('blob:')) return raw;
    if (raw.startsWith('file:')) return kIsWeb ? '' : raw.substring(5);
    if (raw.startsWith('b64:')) return '';
    if (raw.startsWith('data:')) return '';
    final looksLikePath =
        raw.contains('\\') || raw.contains('/') || raw.contains(':');
    if (looksLikePath) {
      return kIsWeb ? '' : raw;
    }
    return '';
  }

  String _photoDataFromRef(String storedRef) {
    final raw = storedRef.trim();
    if (raw.startsWith('b64:')) return raw.substring(4);
    if (raw.startsWith('data:')) return raw;
    if (raw.startsWith('key:')) return '';
    if (raw.startsWith('mem:')) return '';
    if (raw.startsWith('blob:')) return '';
    final looksLikePath =
        raw.contains('\\') || raw.contains('/') || raw.contains(':');
    return looksLikePath ? '' : raw;
  }

  String _photoStoredRefFromRowPhoto(_RowPhoto photo) {
    if (photo.path.trim().isNotEmpty) {
      return 'file:${photo.path}';
    }
    if (photo.dataB64.trim().isNotEmpty) {
      return 'b64:${photo.dataB64}';
    }
    return '';
  }

  int _estimateB64Size(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return 0;
    if (s.startsWith('data:')) {
      final comma = s.indexOf(',');
      if (comma >= 0 && comma < s.length - 1) {
        s = s.substring(comma + 1);
      }
    }
    s = s.replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return 0;
    return ((s.length * 3) / 4).floor();
  }

  PhotoAttachment _photoAttachmentFromRowPhoto(_RowPhoto photo) {
    final storedRef = _photoStoredRefFromRowPhoto(photo);
    final size =
        photo.dataB64.trim().isNotEmpty ? _estimateB64Size(photo.dataB64) : 0;
    return PhotoAttachment(
      id: _genAttachmentId('ph_legacy_'),
      filename: photo.name,
      caption: photo.name,
      mime: photo.mime,
      size: size,
      storedRef: storedRef,
      thumbRef: photo.thumbB64,
      addedAt: photo.addedAt,
      lat: photo.lat,
      lon: photo.lng,
      accuracyM: photo.accuracyM,
      isLastKnown: photo.isLastKnown,
    );
  }

  void _updatePhotoFlowStatus(String? text, {CellRef? target}) {
    _photoFlowClearT?.cancel();
    if (!mounted) return;
    _setEditorState(() {
      _photoFlowStatus = text;
      _photoFlowTarget = text == null ? null : (target ?? _photoFlowTarget);
    });
  }

  void _clearPhotoFlowStatusSoon(
      {Duration delay = const Duration(seconds: 3)}) {
    _photoFlowClearT?.cancel();
    _photoFlowClearT = Timer(delay, () {
      _updatePhotoFlowStatus(null);
    });
  }

  void _startPhotoPickFromGesture({
    required int r,
    required int c,
    required bool fromCamera,
    required BuildContext sheetContext,
  }) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    if (_guardInAppBrowser(DiagnosticActionType.photo)) return;
    if (fromCamera &&
        _guardInsecureContext(
          DiagnosticActionType.photo,
          actionLabel: 'Camara',
        )) {
      return;
    }

    _photoFlowActive = true;
    _updatePhotoFlowStatus(
      'Destino ${_cellLabelForRef(ref)} \u00b7 esperando seleccion',
      target: ref,
    );

    final future = fromCamera
        ? PhotoAcquireService.I.captureFromCamera(context: context)
        : PhotoAcquireService.I.pickFromGallery();

    unawaited(_handlePhotoOutcome(
      future,
      ref,
      fromCamera: fromCamera,
      sheetContext: sheetContext,
    ));
  }

  Future<void> _handlePhotoOutcome(
    Future<PhotoAcquireOutcome> future,
    CellRef targetRef, {
    required bool fromCamera,
    BuildContext? sheetContext,
  }) async {
    final outcome = await future;
    if (!mounted) return;

    if (fromCamera &&
        _isIosWeb &&
        (outcome.cancelled || outcome.blocked || outcome.isError)) {
      final fallbackOutcome = await _offerGalleryFallback();
      if (!mounted) return;
      if (fallbackOutcome != null) {
        await _handlePhotoOutcomeResult(fallbackOutcome, targetRef);
        if (sheetContext != null && mounted && sheetContext.mounted) {
          if (Navigator.of(sheetContext).canPop()) {
            Navigator.of(sheetContext).pop();
          }
        }
        _photoFlowActive = false;
        return;
      }
    }

    await _handlePhotoOutcomeResult(outcome, targetRef);
    if (sheetContext != null && mounted && sheetContext.mounted) {
      if (Navigator.of(sheetContext).canPop()) {
        Navigator.of(sheetContext).pop();
      }
    }
    _photoFlowActive = false;
  }

  Future<PhotoAcquireOutcome?> _offerGalleryFallback() async {
    if (!mounted) return null;
    final future = await showDialog<Future<PhotoAcquireOutcome>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final pal = _palette(ctx);
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: const Text('No se pudo abrir la camara'),
          content: const Text(
            'No se pudo capturar desde camara. ¿Queres elegir desde galeria?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final future = PhotoAcquireService.I.pickFromGallery();
                Navigator.of(ctx).pop(future);
              },
              child: const Text('Elegir galeria'),
            ),
          ],
        );
      },
    );
    if (future == null) return null;
    return await future;
  }

  Future<void> _pickPhotoForCell(int r, int c,
      {bool fromCamera = false}) async {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    final ref = _cellRefAt(r, c);
    if (ref == null) return;

    if (_guardInAppBrowser(DiagnosticActionType.photo)) return;
    if (fromCamera &&
        _guardInsecureContext(
          DiagnosticActionType.photo,
          actionLabel: 'Camara',
        )) {
      return;
    }

    if (fromCamera) {
      final preflightOk = await _runPermissionPreflight(
        storageKey: _kPrefCameraRationaleSeen,
        permissionLabel: 'camara',
        rationaleTitle: 'Permiso de camara',
        rationaleMessage:
            'Usamos la camara para adjuntar evidencia a la celda seleccionada. '
            'Las fotos quedan en tu almacenamiento local.',
        permission: ph.Permission.camera,
      );
      if (!preflightOk) return;
      if (!mounted) return;
    }

    try {
      final future = fromCamera
          ? PhotoAcquireService.I.captureFromCamera(context: context)
          : PhotoAcquireService.I.pickFromGallery();
      await _handlePhotoOutcome(future, ref, fromCamera: fromCamera);
      return;
    } catch (e, st) {
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.photo,
        ok: false,
        message: 'photo_error $e',
      );
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'error',
        error: e.toString(),
        stack: st.toString(),
      );
      _reportFlowError(
        e,
        flow: AppErrorFlow.attachmentPermission,
        operation: 'photo_pick_for_cell',
        stackTrace: st,
        fallbackMessage: _photoMessageForCause('unknown'),
        icon: Icons.photo_outlined,
        diagnosticType: DiagnosticActionType.photo,
      );
      return;
    }
  }

  Future<void> _handlePhotoOutcomeResult(
    PhotoAcquireOutcome outcome,
    CellRef targetRef, {
    bool fromCamera = false,
    int? replaceIndex,
  }) {
    return _processPhotoOutcome(
      outcome,
      targetRef,
      fromCamera: fromCamera,
      replaceIndex: replaceIndex,
    );
  }

  Future<void> _processPhotoOutcome(
    PhotoAcquireOutcome outcome,
    CellRef targetRef, {
    bool fromCamera = false,
    int? replaceIndex,
  }) async {
    var currentOutcome = outcome;
    _setAttachmentProcessing(targetRef, true);
    try {
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
          'Destino $label \u00b7 cancelado',
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
          'Destino $label \u00b7 bloqueado',
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
        _reportFlowErrorMessage(
          msg,
          flow: AppErrorFlow.attachmentPermission,
          operation: 'photo_blocked',
          fallbackMessage:
              'No se pudo acceder a camara o galeria desde este navegador.',
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
        final cause = _decodeLikelyUnsupported(rawMessage: rawMsg)
            ? _causeDecodeUnsupported
            : '';
        final userMsg = cause == _causeDecodeUnsupported
            ? _photoMessageForCause(cause)
            : (readFail ? _EditorScreenState._kPhotoReadErrorMsg : rawMsg);

        _updatePhotoFlowStatus(
          'Destino $label \u00b7 ${readFail ? 'error lectura' : 'error foto'}',
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
        _reportFlowErrorMessage(
          rawMsg,
          flow: AppErrorFlow.attachmentPermission,
          operation: readFail ? 'photo_read_bytes' : 'photo_outcome_error',
          fallbackMessage: userMsg,
          code: cause.isEmpty ? null : cause,
          diagnosticDetails: _buildAttachmentDiagnostic(
            cause: cause.isEmpty ? 'photo_outcome_error' : cause,
            operation: readFail ? 'photo_read_bytes' : 'photo_outcome_error',
            type: DiagnosticActionType.photo,
            error: rawMsg,
          ),
          icon: Icons.photo_outlined,
        );
        return;
      }

      final result = currentOutcome.result!;
      final originalBytes = result.bytes;
      final originalSize = result.size ?? originalBytes.lengthInBytes;
      final fileType = result.reportedMime ?? result.mime;
      if (originalBytes.isEmpty && originalSize <= 0) {
        _updatePhotoFlowStatus(
          'Destino $label \u00b7 bytes vacios',
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
        _reportFlowErrorMessage(
          'empty_bytes',
          flow: AppErrorFlow.attachmentPermission,
          operation: 'photo_empty_bytes',
          fallbackMessage: _photoMessageForCause(_causeDecodeUnsupported),
          code: _causeDecodeUnsupported,
          diagnosticDetails: _buildAttachmentDiagnostic(
            cause: _causeDecodeUnsupported,
            operation: 'photo_empty_bytes',
            type: DiagnosticActionType.photo,
            mime: fileType,
            size: originalSize,
            fileName: result.name,
            error: 'empty_bytes',
          ),
          icon: Icons.photo_outlined,
        );
        return;
      }

      final prepared = await _preparePhotoForStorage(result);
      final bytes = prepared.bytes;
      final fileSize = bytes.lengthInBytes;

      if (!_checkPhotoLimits(targetRef, fileSize, replaceIndex: replaceIndex)) {
        _updatePhotoFlowStatus(
          'Destino $label \u00b7 limite por celda',
          target: targetRef,
        );
        _clearPhotoFlowStatusSoon();
        return;
      }

      final safeMime = prepared.mime.trim().isEmpty
          ? 'application/octet-stream'
          : prepared.mime.trim();

      final sniffedMime = sniffMime(originalBytes, name: result.name);
      final reportedMime = result.mime.trim();
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'bytes_ready',
        fileName: prepared.fileName,
        sniffedMime: sniffedMime.isNotEmpty ? sniffedMime : null,
        reportedMime: reportedMime.isNotEmpty ? reportedMime : null,
        bytes: fileSize > 0 ? fileSize : null,
        fileSize: originalSize,
        fileType: fileType,
      );
      _updatePhotoFlowStatus(
        'Destino $label \u00b7 bytes listos (${_formatBytes(fileSize)})',
        target: targetRef,
      );

      await _refreshAttachmentCapabilitiesIfWeb();

      final attachmentId = _genAttachmentId('ph_');
      var storageLabel = 'unknown';
      String? storageKey;

      final pipeline = await _attachmentPipeline.run<_PreparedPhoto>(
        AttachmentPipelineRequest<_PreparedPhoto>(
          kind: AttachmentKind.photo,
          source:
              fromCamera ? AttachmentSource.capture : AttachmentSource.gallery,
          cellRef: targetRef.compactKey,
          captureCapabilities: kIsWeb,
          pick: () => prepared,
          normalize: (value) => value,
          persist: (value) async {
            final saveHook = _debugSaveImageHook;
            final save = await (saveHook != null
                ? saveHook(
                    cellRef: targetRef,
                    attachmentId: attachmentId,
                    bytes: bytes,
                    originalName: value.fileName,
                    mime: safeMime,
                    webFile: kIsWeb ? (value.webStoredSource ?? bytes) : null,
                  )
                : _attachmentStore.saveImage(
                    cellRef: targetRef,
                    attachmentId: attachmentId,
                    bytes: bytes,
                    originalName: value.fileName,
                    mime: safeMime,
                    webFile: kIsWeb ? (value.webStoredSource ?? bytes) : null,
                  ));
            if (save == null || save.storedRef.trim().isEmpty) {
              throw Exception('storage_blocked: photo_storage_empty_ref');
            }
            storageLabel = save.storageLabel;
            storageKey = save.storageKey;
            if (storageLabel == 'ram' || save.sessionOnly) {
              _warnStorageFallbackOnce('foto');
            }
            DiagnosticsLog.I.updatePhotoAttempt(
              stage: 'stored',
              storageMode: storageLabel,
              storageKey: storageKey ?? save.storedRef,
              bytes: fileSize,
            );
            return save.storedRef;
          },
          bindToCell: (value, storedRef) async {
            if (!mounted) return;
            final previewable = _isPreviewableMime(safeMime, value.fileName);
            final thumbBytes = previewable
                ? (value.thumbBytes ??
                    await _buildThumbBytesForPreview(
                      bytes,
                      maxW: 320,
                      maxH: 320,
                      quality: 74,
                    ))
                : null;
            final thumbB64 = (thumbBytes == null || thumbBytes.isEmpty)
                ? ''
                : base64Encode(thumbBytes);

            final fixOutcome = _debugSkipAttachmentGps
                ? const _GpsOutcome()
                : await _getGpsFixWithFallback(
                    timeout: const Duration(seconds: 8),
                  );
            if (!mounted) return;

            final attachment = PhotoAttachment(
              id: attachmentId,
              filename: value.fileName,
              caption: value.caption,
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
              throw Exception('bind_failed: cell_missing');
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
          },
        ),
      );

      _lastAttachmentCapabilities = pipeline.ok
          ? pipeline.success?.capabilitySnapshot
          : pipeline.failure?.capabilitySnapshot;

      if (!mounted) return;
      if (!pipeline.ok) {
        final failure = pipeline.failure!.error;
        final cause = _legacyCauseFromPipelineReason(failure.code);
        DiagnosticsLog.I.updatePhotoAttempt(
          stage: 'attach_error',
          error: failure.technicalDetail,
          stack: failure.stackTrace?.toString(),
        );
        _updatePhotoFlowStatus(
          'Destino $label \u00b7 fallo (${failure.code})',
          target: targetRef,
        );
        _reportFlowErrorMessage(
          failure.technicalDetail,
          flow: AppErrorFlow.attachmentPermission,
          operation: 'photo_attach_pipeline',
          fallbackMessage: _photoMessageForCause(cause),
          code: cause,
          diagnosticDetails: _buildAttachmentDiagnostic(
            cause: cause,
            operation: 'photo_attach_pipeline',
            operationId: failure.operationId,
            step: failure.step.name,
            type: DiagnosticActionType.photo,
            mime: safeMime,
            size: fileSize,
            fileName: prepared.fileName,
            error: failure.technicalDetail,
            stackTrace: failure.stackTrace,
          ),
          icon: Icons.photo_outlined,
          diagnosticType: DiagnosticActionType.photo,
        );
        return;
      }

      final storedRef = pipeline.success!.storedRef;
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.photo,
        ok: true,
        message:
            'photo_saved cell=$label name=${result.name} size=$fileSize ref=$storedRef storage=$storageLabel pipeline=${pipeline.operationId}',
      );
      final sizeLabel = _formatBytes(fileSize);
      _showActionSnack(
        'Foto guardada en celda $label ($sizeLabel).',
        isError: false,
        icon: Icons.photo_outlined,
      );
      _updatePhotoFlowStatus(
        'Destino $label \u00b7 guardada',
        target: targetRef,
      );
      _clearPhotoFlowStatusSoon();
    } finally {
      _setAttachmentProcessing(targetRef, false);
    }
  }

  bool _checkPhotoLimits(CellRef ref, int incomingBytes, {int? replaceIndex}) {
    final current = _cellMeta[ref.key];
    final photos = current?.photos ?? const <PhotoAttachment>[];
    final count = photos.length;
    final totalBytes = photos.fold<int>(0, (sum, p) => sum + p.size);

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

  void _addPhotoToCell(int r, int c, PhotoAttachment attachment) {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final current = _cellMeta[ref.key];
    final photos = <PhotoAttachment>[
      ...?current?.photos,
      attachment,
    ];
    final next = CellMeta(
      gps: current?.gps,
      photos: photos,
      audios: current?.audios ?? const <AudioAttachment>[],
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);
  }

  Future<void> _deletePhotoFromCell(int r, int c, int index) async {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final current = _cellMeta[ref.key];
    if (current == null) return;
    if (index < 0 || index >= current.photos.length) return;
    final photo = current.photos[index];
    final nextPhotos = List<PhotoAttachment>.from(current.photos)
      ..removeAt(index);
    final next = CellMeta(
      gps: current.gps,
      photos: nextPhotos,
      audios: current.audios,
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);

    if (photo.storedRef.trim().isNotEmpty) {
      await _attachmentStore.delete(photo.storedRef);
    }
  }

  Future<void> _renamePhotoOnCell(
    BuildContext context,
    int r,
    int c,
    int index,
  ) async {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final current = _cellMeta[ref.key];
    if (current == null) return;
    if (index < 0 || index >= current.photos.length) return;

    final original = current.photos[index];
    final initialCaption = original.caption.trim().isNotEmpty
        ? original.caption.trim()
        : _stripExt(original.filename);
    final controller = TextEditingController(text: initialCaption);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final pal = _palette(ctx);
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: const Text('Editar titulo'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Titulo o caption'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    final nextCaption = (picked ?? '').trim();
    if (nextCaption == original.caption) return;

    final updated = original.copyWith(caption: nextCaption);
    final nextPhotos = List<PhotoAttachment>.from(current.photos);
    nextPhotos[index] = updated;
    final next = CellMeta(
      gps: current.gps,
      photos: nextPhotos,
      audios: current.audios,
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);
  }

  void _reorderPhotoOnCell(int r, int c, int from, int to) {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final current = _cellMeta[ref.key];
    if (current == null) return;
    final photos = List<PhotoAttachment>.from(current.photos);
    if (from < 0 || from >= photos.length) return;
    if (to < 0 || to >= photos.length) return;
    final item = photos.removeAt(from);
    final insertAt = from < to ? (to - 1) : to;
    photos.insert(insertAt, item);
    final next = CellMeta(
      gps: current.gps,
      photos: photos,
      audios: current.audios,
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);
  }

  Future<Uint8List?> _loadPhotoBytesFromAttachment(
    PhotoAttachment photo, {
    bool preferThumb = false,
  }) async {
    final ref = photo.storedRef.trim();
    if (ref.startsWith('blob:')) {
      return _attachmentStore.readBytes(ref);
    }
    final path = _photoPathFromRef(photo.storedRef);
    final data = _photoDataFromRef(photo.storedRef);
    final thumb = photo.thumbRef;
    return PhotoBytesResolver.resolve(
      path: preferThumb ? '' : path,
      dataB64: preferThumb ? '' : data,
      thumbB64: thumb,
      readFromPath: _readPhotoBytesFromPath,
      debugTag: photo.filename,
    );
  }

  Future<Uint8List?> _readPhotoBytesFromPath(String path) async {
    final t = path.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('file:') ||
        t.startsWith('key:') ||
        t.startsWith('mem:') ||
        t.startsWith('blob:')) {
      return _attachmentStore.readBytes(t);
    }
    return _attachmentStore.readBytes(t);
  }

  bool _isPreviewableMime(String mime, String name) {
    final m = mime.toLowerCase();
    if (m.contains('png') ||
        m.contains('jpeg') ||
        m.contains('jpg') ||
        m.contains('webp') ||
        m.contains('gif')) {
      return true;
    }
    final n = name.toLowerCase();
    return n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif');
  }

  bool _canPreviewPhoto(PhotoAttachment photo) {
    return _isPreviewableMime(photo.mime, photo.filename);
  }

  Future<void> _downloadPhotoAttachment(PhotoAttachment photo) async {
    final ref = photo.storedRef.trim();
    if (kIsWeb && ref.startsWith('blob:')) {
      final key = ref.substring(5);
      await WebBlobStore.I.download(
        key,
        name: photo.filename,
        mime: photo.mime,
      );
      return;
    }
    final bytes = await _loadPhotoBytesFromAttachment(photo);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('No se pudo descargar la foto.', isError: true);
      return;
    }
    final name = photo.filename.trim().isEmpty ? 'foto' : photo.filename.trim();
    final mime = photo.mime.trim().isEmpty
        ? 'application/octet-stream'
        : photo.mime.trim();
    await _saveExportBytes(name: name, mime: mime, bytes: bytes, share: false);
  }

  Future<void> _openPhotoPreview(
    BuildContext context,
    PhotoAttachment photo,
  ) async {
    final bytes = await _loadPhotoBytesFromAttachment(photo);
    if (!context.mounted) return;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('No se pudo cargar la foto.', isError: true);
      return;
    }
    final previewable = _canPreviewPhoto(photo);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        if (!previewable) {
          final mimeLabel = photo.mime.trim().isEmpty
              ? 'mime desconocido'
              : photo.mime.trim();
          return AppModal(
            title: 'Adjunto guardado',
            child: Text('Guardado sin vista previa (mime=$mimeLabel).'),
            actions: [
              AppButton(
                label: 'Cerrar',
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              AppButton(
                label: 'Descargar',
                variant: AppButtonVariant.secondary,
                onPressed: () => unawaited(_downloadPhotoAttachment(photo)),
              ),
            ],
          );
        }
        final preview = kIsWeb
            ? Center(
                child: WebBlobImage(
                  bytes: bytes,
                  mime: photo.mime,
                  fit: BoxFit.contain,
                ),
              )
            : InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              );
        return AppModal(
          title: photo.filename.trim().isEmpty
              ? 'Vista previa'
              : photo.filename.trim(),
          maxWidth: 960,
          child: AttachmentPreviewModal(preview: preview),
          actions: [
            AppButton(
              label: 'Descargar',
              variant: AppButtonVariant.secondary,
              onPressed: () => unawaited(_downloadPhotoAttachment(photo)),
            ),
            AppButton(
              label: 'Cerrar',
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
  }

  void _openPhotosSheetForCell(int r, int c) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final pal = _palette(ctx);
        return SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (ctx2, setSheetState) {
              Future<void> handleAdd() async {
                await _pickMultiplePhotosForCell(r, c);
                if (!mounted) return;
                setSheetState(() {});
              }

              final media = MediaQuery.of(ctx2);
              final isNarrow = media.size.width < 600;
              final crossAxisCount =
                  isNarrow ? 2 : (media.size.width < 900 ? 3 : 4);

              final photos =
                  _cellMetaAt(r, c)?.photos ?? const <PhotoAttachment>[];

              Widget emptyState() {
                return Center(
                  child: SizedBox(
                    width: 360,
                    child: EmptyState(
                      title: 'Sin adjuntos todavia',
                      message:
                          'Agrega evidencia para esta celda cuando sea necesario.',
                      icon: Icons.photo_outlined,
                      actionLabel: 'Agregar',
                      onAction: handleAdd,
                    ),
                  ),
                );
              }

              Future<void> confirmDelete(PhotoAttachment photo, int idx) async {
                final ok = await _confirmDeleteEvidence(
                  ctx2,
                  name: _photoCaptionFor(photo),
                  cellLabel: CellKey(r, c).a1,
                );
                if (!ok) return;
                await _deletePhotoFromCell(r, c, idx);
                if (!mounted) return;
                setSheetState(() {});
              }

              Widget buildTile(PhotoAttachment p, int idx) {
                final previewable = _canPreviewPhoto(p);
                final label = _photoCaptionFor(p);
                final dateLabel =
                    '${p.addedAt.toLocal()} · ${_formatBytes(p.size)}';

                Widget thumbWidget() {
                  if (!previewable) {
                    return Container(
                      color: pal.cellBg,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.insert_drive_file_outlined,
                        color: pal.fgMuted,
                      ),
                    );
                  }
                  return FutureBuilder<Uint8List?>(
                    future: _loadPhotoBytesFromAttachment(p),
                    builder: (ctx3, snap) {
                      final bytes = snap.data;
                      if (snap.connectionState == ConnectionState.waiting) {
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: pal.cellBg,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                pal.cellBg,
                                pal.hintBg.withValues(alpha: 0.75),
                                pal.cellBg,
                              ],
                            ),
                          ),
                        );
                      }
                      if (snap.hasError) {
                        return Container(
                          color: pal.cellBg,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: pal.fgMuted,
                          ),
                        );
                      }
                      if (bytes == null || bytes.isEmpty) {
                        return Container(
                          color: pal.cellBg,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.photo_outlined,
                            color: pal.fgMuted,
                          ),
                        );
                      }
                      final child = kIsWeb
                          ? WebBlobImage(
                              bytes: bytes,
                              mime: p.mime,
                              fit: BoxFit.cover,
                            )
                          : Image.memory(
                              bytes,
                              fit: BoxFit.cover,
                              cacheWidth: 480,
                              cacheHeight: 480,
                              filterQuality: FilterQuality.low,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            );
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      );
                    },
                  );
                }

                final tile = AttachmentTile(
                  palette: pal,
                  thumb: thumbWidget(),
                  typeIcon: previewable
                      ? Icons.photo_rounded
                      : Icons.insert_drive_file_outlined,
                  label: label,
                  dateLabel: dateLabel,
                  onPreview: () => unawaited(_openPhotoPreview(ctx2, p)),
                  onRename: () =>
                      unawaited(_renamePhotoOnCell(ctx2, r, c, idx)),
                  onDelete: () => confirmDelete(p, idx),
                );

                return DragTarget<int>(
                  onWillAccept: (from) => from != null && from != idx,
                  onAccept: (from) {
                    _reorderPhotoOnCell(r, c, from, idx);
                    setSheetState(() {});
                  },
                  builder: (ctx3, candidate, rejected) {
                    final isTarget = candidate.isNotEmpty;
                    return AnimatedScale(
                      scale: isTarget ? 1.02 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      child: LongPressDraggable<int>(
                        data: idx,
                        feedback: SizedBox(
                          width: 160,
                          child: Opacity(opacity: 0.85, child: tile),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: tile,
                        ),
                        child: tile,
                      ),
                    );
                  },
                );
              }

              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: isNarrow ? 0.85 : 0.75,
                minChildSize: 0.45,
                maxChildSize: 0.95,
                builder: (ctx3, scrollController) {
                  return Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pal.menuBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: pal.border,
                        width: pal.hairline,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: pal.cellText
                              .withValues(alpha: pal.isLight ? 0.05 : 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        AttachmentsSheetHeader(
                          palette: pal,
                          title: 'Evidencias - ${CellKey(r, c).a1}',
                          count: photos.length,
                          onAdd: handleAdd,
                          onClose: () => Navigator.of(ctx3).pop(),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, anim) {
                              final scale = Tween<double>(
                                begin: 0.98,
                                end: 1.0,
                              ).animate(anim);
                              return FadeTransition(
                                opacity: anim,
                                child: ScaleTransition(
                                  scale: scale,
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(photos.isEmpty),
                              child: photos.isEmpty
                                  ? emptyState()
                                  : GridView.builder(
                                      controller: scrollController,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: 0.85,
                                      ),
                                      itemCount: photos.length,
                                      itemBuilder: (ctx4, idx) =>
                                          buildTile(photos[idx], idx),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  DateTime? _latestAttachmentTimestamp(CellMeta meta) {
    DateTime? latest = meta.gps?.timestamp;
    for (final photo in meta.photos) {
      if (latest == null || photo.addedAt.isAfter(latest)) {
        latest = photo.addedAt;
      }
    }
    for (final audio in meta.audios) {
      if (latest == null || audio.addedAt.isAfter(latest)) {
        latest = audio.addedAt;
      }
    }
    return latest;
  }

  (double?, double?, double?) _coordsForMeta(CellMeta meta) {
    final gps = meta.gps;
    if (gps != null) {
      return (gps.lat, gps.lng, gps.accuracyM);
    }
    for (final photo in meta.photos) {
      if (photo.lat != null && photo.lon != null) {
        return (photo.lat, photo.lon, photo.accuracyM);
      }
    }
    return (null, null, null);
  }

  Future<void> _replacePrimaryPhotoForCell(int r, int c) async {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final photos = _cellMeta[ref.key]?.photos ?? const <PhotoAttachment>[];
    if (photos.isEmpty) {
      await _startPhotoFlowForCell(r, c);
      return;
    }

    final picked = await _showPhotoSourcePicker();
    if (!mounted) return;
    if (picked == null) return;

    _photoFlowActive = true;
    _updatePhotoFlowStatus(
      'Destino ${_cellLabelForRef(ref)} - reemplazando foto',
      target: ref,
    );
    await _processPhotoOutcome(
      picked.outcome,
      ref,
      fromCamera: picked.fromCamera,
      replaceIndex: 0,
    );
    _photoFlowActive = false;
  }

  Future<void> _clearAttachmentsForCell(int r, int c) async {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final current = _cellMeta[ref.key];
    if (current == null || current.isEmpty) return;

    final cleanup = <Future<void>>[];
    for (final photo in current.photos) {
      final storedRef = photo.storedRef.trim();
      if (storedRef.isNotEmpty) {
        cleanup.add(_attachmentStore.delete(storedRef));
      }
    }
    for (final audio in current.audios) {
      final storedRef = audio.storedRef.trim();
      if (storedRef.isNotEmpty) {
        cleanup.add(_attachmentStore.delete(storedRef));
      }
    }
    if (cleanup.isNotEmpty) {
      await Future.wait(cleanup, eagerError: false);
    }

    _setCellMetaEntry(
      r,
      c,
      const CellMeta(
        photos: <PhotoAttachment>[],
        audios: <AudioAttachment>[],
      ),
      markDirty: true,
    );
    _refreshCellAfterSave(r, c);
  }

  Future<void> _copyGpsCoordinatesForCell(int r, int c) async {
    final meta = _cellMetaAt(r, c);
    if (meta == null) return;
    final coords = _coordsForMeta(meta);
    final lat = coords.$1;
    final lon = coords.$2;
    if (lat == null || lon == null) {
      _showActionSnack(
        'Esta celda no tiene coordenadas para copiar.',
        isError: true,
        icon: Icons.content_copy_rounded,
      );
      return;
    }
    final payload = '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
    await Clipboard.setData(ClipboardData(text: payload));
    _showActionSnack(
      'Coordenadas copiadas: $payload',
      isError: false,
      icon: Icons.content_copy_rounded,
    );
  }

  Future<void> _openAttachmentPanelForCell(int r, int c) async {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;

    final meta = _cellMetaAt(r, c);
    if (meta == null || meta.isEmpty) {
      _showActionSnack(
        'Sin adjuntos en ${CellKey(r, c).a1}.',
        isError: true,
        icon: Icons.photo_outlined,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final pal = _palette(ctx);
        final currentMeta = _cellMetaAt(r, c) ?? meta;
        final latestTs = _latestAttachmentTimestamp(currentMeta)?.toLocal();
        final coords = _coordsForMeta(currentMeta);
        final lat = coords.$1;
        final lon = coords.$2;
        final precision = coords.$3;
        final hasGps = lat != null && lon != null;
        final hasPhotos = currentMeta.photos.isNotEmpty;
        final hasAudios = currentMeta.audios.isNotEmpty;
        final canOpenViewer = hasPhotos || hasAudios;

        Widget statChip(IconData icon, String label) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: pal.chipBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: pal.chipBorder,
                width: math.max(pal.hairline, 1).toDouble(),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: pal.chipText),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: pal.chipText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }

        Widget metaRow(String label, String value) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: pal.cellTextMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: pal.cellText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.menuBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: pal.gridBorder,
                  width: math.max(pal.hairline, 1).toDouble(),
                ),
                boxShadow: [
                  BoxShadow(
                    color: pal.cellText
                        .withValues(alpha: pal.isLight ? 0.08 : 0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Adjuntos - ${CellKey(r, c).a1}',
                          style: TextStyle(
                            color: pal.cellText,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        tooltip: 'Cerrar',
                        icon:
                            Icon(Icons.close_rounded, color: pal.cellTextMuted),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      statChip(Icons.photo_rounded,
                          'Fotos ${currentMeta.photos.length}'),
                      statChip(Icons.graphic_eq_rounded,
                          'Audios ${currentMeta.audios.length}'),
                      statChip(Icons.my_location_rounded,
                          hasGps ? 'GPS activo' : 'Sin GPS'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    radius: 14,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    color: pal.headerBg,
                    borderColor: pal.border,
                    shadows: const <BoxShadow>[],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Metadata',
                          style: TextStyle(
                            color: pal.cellText,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        metaRow(
                            'Fecha/Hora',
                            latestTs == null
                                ? '-'
                                : _formatDateTimeShort(latestTs)),
                        metaRow(
                          'Lat/Lon',
                          hasGps
                              ? '${lat!.toStringAsFixed(6)}, ${lon!.toStringAsFixed(6)}'
                              : '-',
                        ),
                        metaRow(
                          'Precision',
                          precision == null
                              ? '-'
                              : '${precision.toStringAsFixed(1)} m',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppButton(
                        label: 'Ver',
                        icon: Icons.visibility_outlined,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        onPressed: canOpenViewer
                            ? () {
                                Navigator.of(ctx).pop();
                                if (hasPhotos) {
                                  _openPhotosSheetForCell(r, c);
                                  return;
                                }
                                if (hasAudios) {
                                  _openAudiosSheetForCell(r, c);
                                }
                              }
                            : null,
                      ),
                      AppButton(
                        label: 'Reemplazar',
                        icon: Icons.autorenew_rounded,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          unawaited(_replacePrimaryPhotoForCell(r, c));
                        },
                      ),
                      AppButton(
                        label: 'Eliminar',
                        icon: Icons.delete_outline_rounded,
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.sm,
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final ok = await _confirmDeleteEvidence(
                            context,
                            name: 'adjuntos',
                            cellLabel: CellKey(r, c).a1,
                          );
                          if (!ok) return;
                          await _clearAttachmentsForCell(r, c);
                          _showActionSnack(
                            'Adjuntos eliminados en ${CellKey(r, c).a1}.',
                            isError: false,
                            icon: Icons.delete_outline_rounded,
                          );
                        },
                      ),
                      AppButton(
                        label: 'Copiar coordenadas',
                        icon: Icons.content_copy_rounded,
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.sm,
                        onPressed: hasGps
                            ? () {
                                Navigator.of(ctx).pop();
                                unawaited(_copyGpsCoordinatesForCell(r, c));
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _attachVideoForCell(int r, int c) async {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    if (_guardInAppBrowser(DiagnosticActionType.video)) return;
    if (_guardInsecureContext(
      DiagnosticActionType.video,
      actionLabel: 'Video',
    )) {
      return;
    }

    final typeGroup = XTypeGroup(
      label: 'Video',
      mimeTypes: const <String>[
        'video/mp4',
        'video/quicktime',
        'video/webm',
        'video/x-m4v',
        'video/mpeg',
      ],
      extensions: const <String>[
        'mp4',
        'mov',
        'webm',
        'm4v',
        'mpeg',
      ],
    );
    final xf = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    await _attachGenericFileToCell(
      ref,
      picked: xf,
      kind: AttachmentKind.video,
      diagType: DiagnosticActionType.video,
      icon: Icons.videocam_rounded,
      sourceLabel: 'video',
    );
  }

  Future<void> _attachDocumentForCell(int r, int c) async {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    if (_guardInAppBrowser(DiagnosticActionType.file)) return;

    final typeGroup = XTypeGroup(
      label: 'Archivo',
      mimeTypes: const <String>[
        'application/pdf',
        'text/plain',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/zip',
      ],
      extensions: const <String>[
        'pdf',
        'txt',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'csv',
        'zip',
      ],
    );
    final xf = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    await _attachGenericFileToCell(
      ref,
      picked: xf,
      kind: AttachmentKind.doc,
      diagType: DiagnosticActionType.file,
      icon: Icons.attach_file_rounded,
      sourceLabel: 'archivo',
    );
  }

  Future<void> _attachGenericFileToCell(
    CellRef target, {
    required XFile? picked,
    required AttachmentKind kind,
    required DiagnosticActionType diagType,
    required IconData icon,
    required String sourceLabel,
  }) async {
    final cellLabel = _cellLabelForRef(target);
    _setAttachmentProcessing(target, true);
    try {
      if (picked == null) {
        _showActionSnack(
          'Adjuntar $sourceLabel cancelado.',
          isError: true,
          icon: icon,
        );
        return;
      }

      Uint8List bytes;
      try {
        bytes = await picked.readAsBytes();
      } catch (e, st) {
        final op = '${kind.name}_file_read';
        _reportFlowError(
          e,
          flow: AppErrorFlow.attachmentPermission,
          operation: op,
          stackTrace: st,
          fallbackMessage: 'No se pudo leer el archivo seleccionado.',
          code: 'storage_blocked',
          diagnosticDetails: _buildAttachmentDiagnostic(
            cause: 'storage_blocked',
            operation: op,
            type: diagType,
            fileName: picked.name,
            error: e,
            stackTrace: st,
          ),
          icon: icon,
          diagnosticType: diagType,
        );
        return;
      }

      if (bytes.isEmpty) {
        _reportFlowErrorMessage(
          '${kind.name}_file_empty',
          flow: AppErrorFlow.attachmentPermission,
          operation: '${kind.name}_file_read',
          fallbackMessage: 'El archivo seleccionado esta vacio.',
          code: 'unsupported_format',
          diagnosticDetails: _buildAttachmentDiagnostic(
            cause: 'unsupported_format',
            operation: '${kind.name}_file_read',
            type: diagType,
            fileName: picked.name,
            size: 0,
            error: '${kind.name}_file_empty',
          ),
          icon: icon,
          diagnosticType: diagType,
        );
        return;
      }

      if (!_checkPhotoLimits(target, bytes.lengthInBytes)) {
        return;
      }

      await _refreshAttachmentCapabilitiesIfWeb();

      final inferredMime = (picked.mimeType ?? '').trim().isNotEmpty
          ? picked.mimeType!.trim()
          : _guessMimeFromName(
              picked.name,
              fallback: kind == AttachmentKind.video
                  ? 'video/mp4'
                  : 'application/octet-stream',
            );
      final attachmentId = _genAttachmentId(
        kind == AttachmentKind.video ? 'vd_' : 'fl_',
      );
      var storageLabel = 'unknown';

      final pipeline = await _attachmentPipeline.run<Uint8List>(
        AttachmentPipelineRequest<Uint8List>(
          kind: kind,
          source: AttachmentSource.files,
          cellRef: target.compactKey,
          captureCapabilities: kIsWeb,
          pick: () => bytes,
          normalize: (value) => value,
          persist: (value) async {
            final save = await _attachmentStore.saveImage(
              cellRef: target,
              attachmentId: attachmentId,
              bytes: value,
              originalName: picked.name.trim().isEmpty
                  ? (kind == AttachmentKind.video
                      ? 'video_adjuntado'
                      : 'archivo_adjuntado')
                  : picked.name.trim(),
              mime: inferredMime,
              webFile: kIsWeb ? value : null,
            );
            if (save == null || save.storedRef.trim().isEmpty) {
              throw Exception('storage_blocked: ${kind.name}_store_failed');
            }
            storageLabel = save.storageLabel;
            if (storageLabel == 'ram' || save.sessionOnly) {
              _warnStorageFallbackOnce(sourceLabel);
            }
            return save.storedRef;
          },
          bindToCell: (value, storedRef) async {
            final safeName = picked.name.trim().isEmpty
                ? (kind == AttachmentKind.video
                    ? 'video_adjuntado'
                    : 'archivo_adjuntado')
                : picked.name.trim();
            final thumbB64 = await _buildInlineThumbB64(
              bytes: value,
              mime: inferredMime,
              name: safeName,
            );
            final att = PhotoAttachment(
              id: attachmentId,
              filename: safeName,
              caption: _stripExt(_safeFile(safeName)),
              mime: inferredMime,
              size: value.lengthInBytes,
              storedRef: storedRef,
              thumbRef: thumbB64,
              addedAt: DateTime.now(),
            );
            if (!_applyPhotoToRef(target, att)) {
              throw Exception('bind_failed: cell_missing');
            }
          },
        ),
      );

      _lastAttachmentCapabilities = pipeline.ok
          ? pipeline.success?.capabilitySnapshot
          : pipeline.failure?.capabilitySnapshot;

      if (!mounted) return;
      if (!pipeline.ok) {
        final failure = pipeline.failure!.error;
        final message = _attachmentMessageForFailure(failure, kind: kind);
        final legacyCause = _legacyCauseFromPipelineReason(failure.code);
        _reportFlowErrorMessage(
          failure.technicalDetail,
          flow: AppErrorFlow.attachmentPermission,
          operation: '${kind.name}_attach_pipeline',
          fallbackMessage: message,
          code: legacyCause,
          diagnosticDetails: _buildAttachmentDiagnostic(
            cause: legacyCause,
            operation: '${kind.name}_attach_pipeline',
            operationId: failure.operationId,
            step: failure.step.name,
            type: diagType,
            mime: inferredMime,
            size: bytes.lengthInBytes,
            fileName: picked.name,
            error: failure.technicalDetail,
            stackTrace: failure.stackTrace,
          ),
          icon: icon,
          diagnosticType: diagType,
        );
        return;
      }

      DiagnosticsLog.I.record(
        type: diagType,
        ok: true,
        message:
            '${kind.name}_saved cell=$cellLabel name=${picked.name} size=${bytes.lengthInBytes} ref=${pipeline.success!.storedRef} storage=$storageLabel pipeline=${pipeline.operationId}',
      );
      _showActionSnack(
        '${kind == AttachmentKind.video ? 'Video' : 'Archivo'} guardado en celda $cellLabel.',
        isError: false,
        icon: icon,
      );
    } finally {
      _setAttachmentProcessing(target, false);
    }
  }

  String _guessMimeFromName(String name, {required String fallback}) {
    final lower = name.toLowerCase().trim();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.zip')) return 'application/zip';
    return fallback;
  }

  Future<String> _buildInlineThumbB64({
    required Uint8List bytes,
    required String mime,
    required String name,
  }) async {
    if (_isPreviewableMime(mime, name)) {
      final thumbBytes = await _buildThumbBytesForPreview(
        bytes,
        maxW: 320,
        maxH: 320,
        quality: 74,
      );
      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        return base64Encode(thumbBytes);
      }
      return '';
    }
    if (_isPdfAttachmentMime(mime, name)) {
      if (bytes.lengthInBytes > 256 * 1024) {
        await Future<void>.delayed(Duration.zero);
      }
      final thumbBytes = _tryBuildPdfFirstPageThumb(bytes);
      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        return base64Encode(thumbBytes);
      }
    }
    return '';
  }

  bool _isPdfAttachmentMime(String mime, String name) {
    final m = mime.toLowerCase();
    final n = name.toLowerCase();
    return m.contains('application/pdf') || n.endsWith('.pdf');
  }

  Uint8List? _tryBuildPdfFirstPageThumb(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    // Intento condicional: se requiere rasterizador PDF en runtime; fallback icon.
    return null;
  }

// ------------------------------ Audio -----------------------------------

  String _audioStoredRefFrom(StoredAudio stored) {
    final key = stored.storageKey.trim();
    if (key.isEmpty) return '';
    if (key.startsWith('file:') ||
        key.startsWith('key:') ||
        key.startsWith('mem:')) return key;
    final hasSlash = key.contains('\\') || key.contains('/');
    if (key.contains(':') && !hasSlash) return 'key:$key';
    return hasSlash ? 'file:$key' : 'key:$key';
  }

  String _audioKeyFromRef(String storedRef) {
    final raw = storedRef.trim();
    if (raw.startsWith('file:')) return raw.substring(5);
    if (raw.startsWith('mem:')) return raw;
    if (raw.startsWith('key:')) return raw.substring(4);
    return raw;
  }

  bool _audioIsFileRef(String storedRef) {
    final raw = storedRef.trim();
    if (raw.startsWith('file:')) return true;
    if (raw.startsWith('key:') || raw.startsWith('mem:')) return false;
    return raw.contains('\\') || raw.contains('/') || raw.contains(':');
  }

  String _formatDuration(Duration d) {
    final totalSec = d.inSeconds;
    final min = (totalSec ~/ 60).toString().padLeft(2, '0');
    final sec = (totalSec % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  String _audioStartErrorMessage(Object e) {
    final cause = _audioErrorCode(e);
    if (cause == _causeMicDenied) return _audioMessageForCause(cause);
    if (cause == _causeMicUnsupported) return _audioMessageForCause(cause);
    final raw = e.toString().toLowerCase();
    if (raw.contains('insecure') || raw.contains('https')) {
      return 'Necesitas HTTPS para grabar audio.';
    }
    return _audioMessageForCause('');
  }

  bool _supportsSystemPermissionSettings() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<bool> _runPermissionPreflight({
    required String storageKey,
    required String permissionLabel,
    required String rationaleTitle,
    required String rationaleMessage,
    required ph.Permission permission,
  }) async {
    final canOpenSettings = _supportsSystemPermissionSettings();
    if (canOpenSettings) {
      final status = await permission.status;
      if (status.isPermanentlyDenied || status.isRestricted) {
        await _showPermissionSettingsDialog(
          permissionLabel: permissionLabel,
          canOpenSettings: true,
        );
        return false;
      }
    }

    final seenRationale = await _readPermissionRationaleSeen(storageKey);
    if (seenRationale) return true;

    final continueFlow = await _showPermissionRationaleDialog(
      title: rationaleTitle,
      message: rationaleMessage,
    );
    if (!continueFlow) return false;

    await _writePermissionRationaleSeen(storageKey);
    return true;
  }

  Future<bool> _readPermissionRationaleSeen(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writePermissionRationaleSeen(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {}
  }

  Future<bool> _showPermissionRationaleDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final pal = _palette(ctx);
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Ahora no'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _showPermissionSettingsDialog({
    required String permissionLabel,
    required bool canOpenSettings,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final pal = _palette(ctx);
        final label = permissionLabel.trim();
        final sentence =
            label.isEmpty ? 'este permiso' : 'el permiso de $label';
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: const Text('Permiso bloqueado'),
          content: Text(
            canOpenSettings
                ? 'Parece que $sentence esta bloqueado de forma permanente. '
                    'Abre configuracion para habilitarlo.'
                : 'Parece que $sentence esta bloqueado. '
                    'Habilitalo desde la configuracion del navegador o sistema.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
            if (canOpenSettings)
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final opened = await ph.openAppSettings();
                    if (!opened && mounted) {
                      _showActionSnack(
                        'No se pudo abrir configuracion automaticamente.',
                        isError: true,
                        icon: Icons.settings_outlined,
                      );
                    }
                  } catch (e, st) {
                    _reportFlowError(
                      e,
                      flow: AppErrorFlow.attachmentPermission,
                      operation: 'open_permission_settings',
                      stackTrace: st,
                      fallbackMessage:
                          'No se pudo abrir configuracion automaticamente.',
                      icon: Icons.settings_outlined,
                    );
                  }
                },
                child: const Text('Abrir configuración'),
              ),
          ],
        );
      },
    );
  }

  Future<bool> _offerAudioFileFallback(
    CellRef ref, {
    required String cause,
  }) async {
    if (!mounted) return false;
    final cellLabel = _cellLabelForRef(ref);
    final pickFile = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final pal = _palette(ctx);
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: const Text('Grabacion no disponible'),
          content: Text(
            'No se puede grabar audio en este navegador para la celda $cellLabel.\n\n'
            'Puedes adjuntar un audio existente desde archivo.\n'
            'Causa: $cause.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Adjuntar audio desde archivo'),
            ),
          ],
        );
      },
    );
    if (pickFile != true) return false;
    await _attachAudioFromFile(ref);
    return true;
  }

  Future<void> _attachAudioFromFile(CellRef ref) async {
    final typeGroup = XTypeGroup(
      label: 'Audio',
      mimeTypes: const <String>[
        'audio/mp4',
        'audio/mpeg',
        'audio/aac',
        'audio/webm',
        'audio/wav',
        'audio/x-wav',
      ],
      extensions: const <String>[
        'm4a',
        'mp3',
        'aac',
        'webm',
        'wav',
        'ogg',
      ],
    );

    final xf = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (!mounted) return;
    if (xf == null) {
      _showActionSnack(
        'Adjuntar audio cancelado.',
        isError: true,
        icon: Icons.audiotrack_rounded,
      );
      return;
    }

    Uint8List bytes;
    try {
      bytes = await xf.readAsBytes();
    } catch (e, st) {
      _reportFlowError(
        e,
        flow: AppErrorFlow.attachmentPermission,
        operation: 'audio_file_read',
        stackTrace: st,
        fallbackMessage: _audioMessageForCause(_causeStorageBlocked),
        code: _causeStorageBlocked,
        diagnosticDetails: _buildAttachmentDiagnostic(
          cause: _causeStorageBlocked,
          operation: 'audio_file_read',
          type: DiagnosticActionType.audio,
          fileName: xf.name,
          error: e,
          stackTrace: st,
        ),
        icon: Icons.mic_off_rounded,
        diagnosticType: DiagnosticActionType.audio,
      );
      return;
    }

    if (bytes.isEmpty) {
      _reportFlowErrorMessage(
        'audio_file_empty',
        flow: AppErrorFlow.attachmentPermission,
        operation: 'audio_file_read',
        fallbackMessage: _audioMessageForCause(_causeStorageBlocked),
        code: _causeStorageBlocked,
        diagnosticDetails: _buildAttachmentDiagnostic(
          cause: _causeStorageBlocked,
          operation: 'audio_file_read',
          type: DiagnosticActionType.audio,
          fileName: xf.name,
          error: 'audio_file_empty',
        ),
        icon: Icons.mic_off_rounded,
        diagnosticType: DiagnosticActionType.audio,
      );
      return;
    }

    final mime = (xf.mimeType ?? '').trim().isNotEmpty
        ? xf.mimeType!.trim()
        : _guessAudioMimeFromName(xf.name);
    final recording = RecordedAudio(
      fileName: xf.name.trim().isEmpty ? 'audio_adjuntado' : xf.name.trim(),
      mime: mime.isEmpty ? 'audio/mpeg' : mime,
      duration: Duration.zero,
      bytes: bytes,
    );
    await _saveAudioAttachment(ref, recording, source: 'file');
  }

  String _guessAudioMimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.webm')) return 'audio/webm';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return '';
  }

  Future<void> _saveAudioAttachment(
    CellRef target,
    RecordedAudio recording, {
    required String source,
  }) async {
    await _refreshAttachmentCapabilitiesIfWeb();
    final attachmentId = _genAttachmentId('au_');
    final usedSource =
        source == 'record' ? AttachmentSource.record : AttachmentSource.files;
    String? storageKey;
    int storedSize = recording.bytes?.lengthInBytes ?? 0;

    final pipeline = await _attachmentPipeline.run<RecordedAudio>(
      AttachmentPipelineRequest<RecordedAudio>(
        kind: AttachmentKind.audio,
        source: usedSource,
        cellRef: target.compactKey,
        captureCapabilities: kIsWeb,
        pick: () => recording,
        normalize: (value) => value,
        persist: (value) async {
          final stored = await _audioStore.saveRecording(
            sheetId: widget.sheetId,
            cellKey: target.compactKey,
            attachmentId: attachmentId,
            recording: value,
          );
          if (stored == null) {
            throw Exception('storage_blocked: audio_storage_save_failed');
          }
          storedSize = stored.bytesLength;
          storageKey = stored.storageKey;
          final storedRef = _audioStoredRefFrom(stored);
          if (storedRef.startsWith('mem:')) {
            _warnStorageFallbackOnce('audio');
          }
          return storedRef;
        },
        bindToCell: (value, storedRef) async {
          final attachment = AudioAttachment(
            id: attachmentId,
            filename: value.fileName,
            mime: value.mime,
            size: storedSize,
            durationMs: value.duration.inMilliseconds,
            storedRef: storedRef,
            addedAt: DateTime.now(),
          );
          final idx = _cellIndexForRef(target);
          if (idx == null) {
            throw Exception('bind_failed: cell_missing');
          }
          _addAudioToCell(idx.r, idx.c, attachment);
        },
      ),
    );

    _lastAttachmentCapabilities = pipeline.ok
        ? pipeline.success?.capabilitySnapshot
        : pipeline.failure?.capabilitySnapshot;

    if (!mounted) return;
    if (!pipeline.ok) {
      final failure = pipeline.failure!.error;
      final cause = _legacyCauseFromPipelineReason(failure.code);
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.audio,
        ok: false,
        message: 'audio_save_failed ${failure.technicalDetail}',
      );
      _reportFlowErrorMessage(
        failure.technicalDetail,
        flow: AppErrorFlow.attachmentPermission,
        operation: 'audio_store_pipeline',
        fallbackMessage: _audioMessageForCause(cause),
        code: cause,
        diagnosticDetails: _buildAttachmentDiagnostic(
          cause: cause,
          operation: 'audio_store_pipeline',
          operationId: failure.operationId,
          step: failure.step.name,
          type: DiagnosticActionType.audio,
          mime: recording.mime,
          size: recording.bytes?.lengthInBytes,
          fileName: recording.fileName,
          error: failure.technicalDetail,
          stackTrace: failure.stackTrace,
          extra: <String, String>{
            if ((storageKey ?? '').trim().isNotEmpty) 'storageKey': storageKey!,
          },
        ),
        icon: Icons.mic_off_rounded,
        diagnosticType: DiagnosticActionType.audio,
      );
      return;
    }

    final storedRef = pipeline.success!.storedRef;
    final cellLabel = _cellLabelForRef(target);
    DiagnosticsLog.I.record(
      type: DiagnosticActionType.audio,
      ok: true,
      message:
          'audio_saved source=$source cell=$cellLabel name=${recording.fileName} size=$storedSize ref=$storedRef pipeline=${pipeline.operationId}',
    );
    final modeLabel = source == 'record' ? 'audio' : 'audio archivo';
    _showActionSnack(
      'Guardado en celda $cellLabel ($modeLabel).',
      isError: false,
      icon: Icons.mic_rounded,
    );
  }

  Future<void> _startAudioRecordingForCell(int r, int c) async {
    if (_audioRecording) {
      final cell = _recordingAudioCellRef;
      final label = _cellLabelForRef(cell);
      _showActionSnack(
        label.isEmpty
            ? 'Ya hay una grabacion en curso.'
            : 'Ya hay una grabacion en curso en celda $label.',
        isError: false,
        icon: Icons.mic_rounded,
      );
      return;
    }

    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    if (_guardInAppBrowser(DiagnosticActionType.audio)) return;
    if (_guardInsecureContext(DiagnosticActionType.audio)) return;

    await _refreshAttachmentCapabilitiesIfWeb();

    if (kIsWeb) {
      _lastAudioSupport = await WebAudioRecorder.I.probeSupport();
      if (!(_lastAudioSupport?.isSupported ?? false)) {
        final cause = _causeMicUnsupported;
        final usedFallback = await _offerAudioFileFallback(
          ref,
          cause: cause,
        );
        if (usedFallback) return;
        _reportFlowErrorMessage(
          'media_recorder_unavailable',
          flow: AppErrorFlow.attachmentPermission,
          operation: 'audio_support_probe',
          fallbackMessage: _audioMessageForCause(cause),
          code: cause,
          diagnosticDetails: _buildAttachmentDiagnostic(
            cause: cause,
            operation: 'audio_support_probe',
            type: DiagnosticActionType.audio,
            extra: <String, String>{
              'mediaRecorderAvailable':
                  '${_lastAudioSupport?.mediaRecorderAvailable ?? false}',
              'selectedMime': _lastAudioSupport?.selectedMimeType ?? 'none',
            },
          ),
          icon: Icons.mic_off_rounded,
          diagnosticType: DiagnosticActionType.audio,
        );
        return;
      }
    }

    final preflightOk = await _runPermissionPreflight(
      storageKey: _kPrefMicrophoneRationaleSeen,
      permissionLabel: 'microfono',
      rationaleTitle: 'Permiso de microfono',
      rationaleMessage:
          'Usamos el microfono para grabar notas de voz en la celda activa. '
          'Los audios quedan en tu almacenamiento local.',
      permission: ph.Permission.microphone,
    );
    if (!preflightOk) return;

    try {
      await _audioService.startRecording(sheetId: widget.sheetId);
    } catch (e, st) {
      if (!mounted) return;
      final cause = _audioErrorCode(e);
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.audio,
        ok: false,
        message: 'audio_start_failed $e',
      );
      final usedFallback = cause == _causeMicUnsupported
          ? await _offerAudioFileFallback(
              ref,
              cause: cause,
            )
          : false;
      if (!mounted) return;
      if (usedFallback) return;
      _reportFlowError(
        e,
        flow: AppErrorFlow.attachmentPermission,
        operation: 'audio_start_recording',
        stackTrace: st,
        fallbackMessage: _audioStartErrorMessage(e),
        code: cause.isEmpty ? null : cause,
        diagnosticDetails: _buildAttachmentDiagnostic(
          cause: cause.isEmpty ? 'audio_start_failed' : cause,
          operation: 'audio_start_recording',
          type: DiagnosticActionType.audio,
          error: e,
          stackTrace: st,
          extra: <String, String>{
            'selectedMime': _lastAudioSupport?.selectedMimeType ?? 'unknown',
          },
        ),
        icon: Icons.mic_off_rounded,
        diagnosticType: DiagnosticActionType.audio,
      );
      return;
    }

    if (!mounted) return;
    _setEditorState(() {
      _audioRecording = true;
      _recordingAudioCellRef = ref;
    });
    final cellLabel = _cellLabelForRef(ref);
    _showActionSnack('Grabando audio en celda $cellLabel...',
        isError: false, icon: Icons.mic_rounded);
  }

  Future<void> _stopAudioRecording() async {
    if (!_audioRecording) return;
    final target = _recordingAudioCellRef;
    final recording = await _audioService.stopRecording();
    if (!mounted) return;

    _setEditorState(() {
      _audioRecording = false;
      _recordingAudioCellRef = null;
    });

    if (recording == null || target == null) {
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.audio,
        ok: false,
        message: 'audio_save_empty',
      );
      _showActionSnack('No se guardo el audio.',
          isError: true, icon: Icons.mic_off_rounded);
      return;
    }
    await _saveAudioAttachment(target, recording, source: 'record');
  }

  void _addAudioToCell(int r, int c, AudioAttachment attachment) {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final current = _cellMeta[ref.key];
    final audios = <AudioAttachment>[
      ...?current?.audios,
      attachment,
    ];
    final next = CellMeta(
      gps: current?.gps,
      photos: current?.photos ?? const <PhotoAttachment>[],
      audios: audios,
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);
  }

  Future<void> _deleteAudioFromCell(int r, int c, int index) async {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final current = _cellMeta[ref.key];
    if (current == null) return;
    if (index < 0 || index >= current.audios.length) return;
    final audio = current.audios[index];
    final nextAudios = List<AudioAttachment>.from(current.audios)
      ..removeAt(index);
    final next = CellMeta(
      gps: current.gps,
      photos: current.photos,
      audios: nextAudios,
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);

    if (_playingAudioId == audio.id) {
      await _audioPlayer.stop();
      _setEditorState(() => _playingAudioId = null);
    }

    final keyRef = _audioKeyFromRef(audio.storedRef);
    if (keyRef.trim().isNotEmpty) {
      await _audioStore.deleteAudio(keyRef);
    }
  }

  Future<void> _renameAudioOnCell(
    BuildContext context,
    int r,
    int c,
    int index,
  ) async {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final current = _cellMeta[ref.key];
    if (current == null) return;
    if (index < 0 || index >= current.audios.length) return;

    final original = current.audios[index];
    final controller = TextEditingController(text: original.filename);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final pal = _palette(ctx);
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: const Text('Renombrar audio'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    final nextName = (picked ?? '').trim();
    if (nextName.isEmpty || nextName == original.filename) return;

    final updated = original.copyWith(filename: nextName);
    final nextAudios = List<AudioAttachment>.from(current.audios);
    nextAudios[index] = updated;
    final next = CellMeta(
      gps: current.gps,
      photos: current.photos,
      audios: nextAudios,
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);
  }

  Future<void> _playAudioAttachment(AudioAttachment audio) async {
    if (_audioRecording) {
      _showSnack('Detén la grabación para reproducir.', isError: false);
      return;
    }

    if (_playingAudioId == audio.id) {
      await _audioPlayer.stop();
      _setEditorState(() => _playingAudioId = null);
      return;
    }

    await _audioPlayer.stop();
    if (!mounted) return;

    final keyRef = _audioKeyFromRef(audio.storedRef);
    if (keyRef.trim().isEmpty) return;

    if (_audioIsFileRef(audio.storedRef) && !kIsWeb) {
      await _audioPlayer.play(DeviceFileSource(keyRef));
    } else {
      final bytes = await _audioStore.readAudioBytes(keyRef);
      if (bytes == null || bytes.isEmpty) return;
      await _audioPlayer.play(BytesSource(bytes));
    }

    if (!mounted) return;
    _setEditorState(() => _playingAudioId = audio.id);
  }

  void _openAudiosSheetForCell(int r, int c) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    final audios = _cellMetaAt(r, c)?.audios ?? const <AudioAttachment>[];
    if (audios.isEmpty) return;
    final pal = _palette(context);
    showAppModal<void>(
      context: context,
      title: 'Audios - ${CellKey(r, c).a1}',
      child: SizedBox(
        height: math.min(MediaQuery.sizeOf(context).height * 0.6, 420),
        child: ListView.separated(
          itemCount: audios.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx2, idx) {
            final a = audios[idx];
            final playing = _playingAudioId == a.id;
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pal.headerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pal.border, width: pal.hairline),
              ),
              child: Row(
                children: [
                  Tooltip(
                    message: playing ? 'Detener' : 'Reproducir',
                    child: IconButton(
                      onPressed: () => unawaited(_playAudioAttachment(a)),
                      icon: Icon(
                        playing
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_fill_rounded,
                        color: pal.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.audiotrack_rounded, color: pal.fgMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: a.filename,
                          child: Text(
                            a.filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: pal.fg,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(
                            Duration(milliseconds: a.durationMs),
                          ),
                          style: TextStyle(
                            color: pal.fgMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: 'Renombrar',
                    child: IconButton(
                      onPressed: () =>
                          unawaited(_renameAudioOnCell(ctx2, r, c, idx)),
                      icon: Icon(Icons.edit_rounded, color: pal.fgMuted),
                    ),
                  ),
                  Tooltip(
                    message: 'Eliminar',
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(ctx2).pop();
                        unawaited(_deleteAudioFromCell(r, c, idx));
                      },
                      icon: Icon(Icons.delete_outline_rounded,
                          color: pal.fgMuted),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        AppButton(
          label: 'Cerrar',
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
  }

  Future<void> _openMobileHeaderMenu(
    BuildContext context,
    _SheetPalette pal,
  ) async {
    await showAppModal<void>(
      context: context,
      title: 'Acciones',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: '+ Registro',
            icon: Icons.add_box_outlined,
            variant: AppButtonVariant.primary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_startQuickCaptureFlow());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Formulario',
            icon: Icons.description_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(
                _openRowFormMode(
                  rowIndex: _selRow,
                  createNew: false,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Adjuntar en celda activa',
            icon: Icons.attach_file_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openAttachmentPanelForCell(_selRow, _selCol));
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Guardar',
            icon: Icons.check_circle_outline_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_saveLocalNow());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Cola offline',
            icon: Icons.sync_alt_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openOfflineQueueDialog());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Exportar / Compartir',
            icon: Icons.ios_share_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openExportMenu());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Ver atajos',
            icon: Icons.keyboard_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openShortcutsHelp());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Ver tour rapido',
            icon: Icons.explore_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              _reopenEditorTour();
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Importar paquete',
            icon: Icons.file_open_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openImportPackageDialog());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Smoke Test (GPS/Foto/Audio)',
            icon: Icons.science_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_runAttachmentSmokeTest());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Agregar fila',
            icon: Icons.add_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              _insertRow(_rows.length);
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Acciones por lote',
            icon: Icons.layers_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openBatchActionsSheet());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Marcar revisado',
            icon: Icons.verified_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_markSelectedRowsReviewed());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: _reviewFilterMode == _ReviewFilterMode.pending
                ? 'Quitar vista pendientes'
                : 'Vista pendientes',
            icon: _reviewFilterMode == _ReviewFilterMode.pending
                ? Icons.filter_alt_off_rounded
                : Icons.pending_actions_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              _togglePendingReviewView();
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Vista urgentes',
            icon: Icons.priority_high_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_activateUrgentViewShortcut());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Auto-ID',
            icon: Icons.tag_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              _applyAutoIdQuick();
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Ir a errores',
            icon: Icons.rule_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              _jumpToFirstValidationIssue();
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Historial',
            icon: Icons.history_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openHistoryPanel());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Panel columnas',
            icon: Icons.view_column_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openColumnPanel());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Guardar vista',
            icon: Icons.bookmark_add_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openSaveViewDialog());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Gestionar vistas',
            icon: Icons.table_view_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openSavedViewsManager());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Preferencias de editor',
            icon: Icons.tune_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openEditorDefaultsDialog());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: _mobileCompactModeEnabled
                ? 'Modo compacto: ON'
                : 'Modo compacto: OFF',
            icon: _mobileCompactModeEnabled
                ? Icons.view_compact_alt_rounded
                : Icons.view_day_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(
                _setEditorDefaultRules(
                  mobileCompactModeEnabled: !_mobileCompactModeEnabled,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Deshacer',
            icon: Icons.undo_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              _undoOnce();
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Rehacer',
            icon: Icons.redo_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              _redoOnce();
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: pal.isLight ? 'Modo oscuro' : 'Modo claro',
            icon: pal.isLight
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              _toggleTheme();
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: _engineHasBase ? 'Calcular' : 'Calcular (local)',
            icon: Icons.functions_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: !_engineBusy
                ? () {
                    Navigator.of(context).pop();
                    unawaited(_computeEngine());
                  }
                : null,
          ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Cerrar',
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
  }

  Future<_PreparedPhoto> _preparePhotoForStorage(
    PhotoAcquireResult result,
  ) async {
    final rawName = result.name.trim().isEmpty ? 'foto' : result.name.trim();
    final safeName = _safeFile(rawName);
    final captionBase = _stripExt(safeName);
    final originalMime = result.mime.trim().isEmpty
        ? 'application/octet-stream'
        : result.mime.trim();

    final enableBrowserNormalizer = kIsWeb || _debugForceWebImageNormalization;
    final needsBrowserNormalize = enableBrowserNormalizer &&
        result.bytes.isNotEmpty &&
        (kIsWeb ||
            result.webFile != null ||
            _isHeicLike(mime: originalMime, name: safeName) ||
            _isDecodeFailed(result.bytes));
    if (needsBrowserNormalize) {
      try {
        final normalized = await _webImageNormalizer.normalize(
          WebImageNormalizationRequest(
            bytes: result.bytes,
            fileName: safeName,
            mimeType: originalMime,
            source: result.webFile,
            maxSide: 1600,
            thumbMaxSide: 320,
            jpegQuality: 0.85,
            thumbJpegQuality: 0.74,
          ),
        );
        if (normalized != null && normalized.bytes.isNotEmpty) {
          return _PreparedPhoto(
            bytes: normalized.bytes,
            mime: normalized.mimeType,
            fileName: _safeFile(normalized.fileName),
            caption: captionBase,
            originalName: rawName,
            wasCompressed: true,
            thumbBytes: normalized.thumbBytes,
            webStoredSource: normalized.bytes,
          );
        }
      } catch (e, st) {
        DiagnosticsLog.I.updatePhotoAttempt(
          stage: 'web_normalize_failed',
          error: e.toString(),
          stack: st.toString(),
        );
      }
      if (_debugForceWebImageNormalization) {
        return _PreparedPhoto(
          bytes: result.bytes,
          mime: originalMime,
          fileName: safeName,
          caption: captionBase,
          originalName: rawName,
          wasCompressed: false,
          webStoredSource: kIsWeb ? result.bytes : null,
        );
      }
    }

    try {
      final params = _CompressParams(
        bytes: result.bytes,
        maxSide: 1600,
        quality: 80,
      );
      final compressed = await _compressPhotoPayload(params);
      if (compressed.bytes.isNotEmpty &&
          compressed.width > 0 &&
          compressed.height > 0) {
        final jpgName = '${_stripExt(safeName)}.jpg';
        return _PreparedPhoto(
          bytes: compressed.bytes,
          mime: 'image/jpeg',
          fileName: jpgName,
          caption: captionBase,
          originalName: rawName,
          wasCompressed: true,
          webStoredSource: kIsWeb ? compressed.bytes : null,
        );
      }
    } catch (_) {}

    return _PreparedPhoto(
      bytes: result.bytes,
      mime: originalMime,
      fileName: safeName,
      caption: captionBase,
      originalName: rawName,
      wasCompressed: false,
      webStoredSource: kIsWeb ? result.bytes : null,
    );
  }

  Future<_CompressResult> _compressPhotoPayload(_CompressParams params) async {
    if (_isWidgetTestRuntime) {
      return await Future<_CompressResult>.microtask(
        () => _compressImageIsolate(params),
      );
    }

    if (!kIsWeb) {
      try {
        return await compute<_CompressParams, _CompressResult>(
          _compressImageIsolate,
          params,
        );
      } catch (_) {
        return await Future<_CompressResult>.microtask(
          () => _compressImageIsolate(params),
        );
      }
    }

    // Web: ceder el hilo antes del fallback CPU para no bloquear input/render.
    await Future<void>.delayed(Duration.zero);
    return await Future<_CompressResult>.microtask(
      () => _compressImageIsolate(params),
    );
  }

  Future<Uint8List?> _buildThumbBytesForPreview(
    Uint8List bytes, {
    required int maxW,
    required int maxH,
    required int quality,
  }) async {
    if (bytes.isEmpty) return null;
    if (_isWidgetTestRuntime) {
      return _compressThumb(bytes, maxW: maxW, maxH: maxH, quality: quality);
    }

    if (!kIsWeb) {
      try {
        return await compute<_ThumbCompressParams, Uint8List?>(
          _compressThumbIsolate,
          _ThumbCompressParams(
            bytes: bytes,
            maxW: maxW,
            maxH: maxH,
            quality: quality,
          ),
        );
      } catch (_) {
        // fallback sync below
      }
    } else if (bytes.lengthInBytes > 256 * 1024) {
      await Future<void>.delayed(Duration.zero);
    }
    return _compressThumb(bytes, maxW: maxW, maxH: maxH, quality: quality);
  }

  bool _isDecodeFailed(Uint8List bytes) {
    try {
      return img.decodeImage(bytes) == null;
    } catch (_) {
      return true;
    }
  }

  Uint8List? _compressThumb(Uint8List bytes,
      {required int maxW, required int maxH, required int quality}) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final oriented = img.bakeOrientation(decoded);
      final maxSide = math.max(maxW, maxH);
      final maxSrc = math.max(oriented.width, oriented.height);
      final resized = maxSrc > maxSide
          ? img.copyResize(
              oriented,
              width: oriented.width > oriented.height ? maxW : null,
              height: oriented.height >= oriented.width ? maxH : null,
              interpolation: img.Interpolation.average,
            )
          : oriented;

      final jpg = img.encodeJpg(resized, quality: quality);
      return Uint8List.fromList(jpg);
    } catch (_) {
      return null;
    }
  }
}
