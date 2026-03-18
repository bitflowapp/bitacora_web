part of '../editor_screen.dart';

extension _EditorExportShareHelpers on _EditorScreenState {
  String _exportShareSubject(String name) =>
      'BitFlow | ${EditorExportOutcomeFactory.shareFormatLabelFromFileName(name)} | $name';

  String _exportShareText(String name) =>
      '${EditorExportOutcomeFactory.shareFormatLabelFromFileName(name)} exportado desde BitFlow: $name';

  EditorExportOutcome _buildSavedExportFlowResult({
    required String name,
    required bool shareRequested,
    required bool includeAttachments,
    String? savedPath,
  }) {
    final path = (savedPath ?? '').trim();
    return EditorExportOutcomeFactory.saved(
      name: name,
      shareRequested: shareRequested,
      includeAttachments: includeAttachments,
      savedPath: path.isEmpty ? null : path,
    );
  }

  EditorExportOutcome _buildDownloadStartedExportFlowResult({
    required String name,
    required bool shareRequested,
    required bool includeAttachments,
    String? message,
  }) {
    return EditorExportOutcomeFactory.downloadStarted(
      name: name,
      shareRequested: shareRequested,
      includeAttachments: includeAttachments,
      message: message,
    );
  }

  EditorExportOutcome _buildShareOpenedExportFlowResult({
    required String name,
    required bool includeAttachments,
    String? message,
  }) {
    return EditorExportOutcomeFactory.shareOpened(
      name: name,
      includeAttachments: includeAttachments,
      message: message,
    );
  }

  EditorExportOutcome _buildSystemSheetOpenedExportFlowResult({
    required String name,
    required bool includeAttachments,
  }) {
    return EditorExportOutcomeFactory.systemSheetOpened(
      name: name,
      includeAttachments: includeAttachments,
    );
  }

  Future<void> _shareExportParams(ShareParams params) async {
    final hook = _debugShareHook;
    if (hook != null) {
      await hook(params);
      return;
    }
    await SharePlus.instance.share(params);
  }

  Future<FileSaveLocation?> _pickExportSaveLocation({
    required String suggestedName,
    required List<XTypeGroup> acceptedTypeGroups,
  }) async {
    final hook = _debugSaveLocationHook;
    if (hook != null) {
      return hook(
        suggestedName: suggestedName,
        acceptedTypeGroups: acceptedTypeGroups,
      );
    }
    return getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: acceptedTypeGroups,
    );
  }

  Future<void> _saveExportFileTo(XFile file, String path) async {
    final hook = _debugSaveFileHook;
    if (hook != null) {
      await hook(file, path);
      return;
    }
    await file.saveTo(path);
  }

  Future<String?> _persistShareExportTempFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final hook = _debugPersistShareTempFileHook;
    if (hook != null) {
      return hook(fileName: fileName, bytes: bytes);
    }
    return persistShareTempFile(fileName: fileName, bytes: bytes);
  }

  Future<EditorExportOutcome> _saveExportBytes({
    required String name,
    required String mime,
    required Uint8List bytes,
    required bool share,
    required bool includeAttachments,
    bool Function()? shouldCancel,
    String? shareSubject,
    String? shareText,
  }) async {
    _throwIfOperationCancelledBy(shouldCancel);
    final xf = XFile.fromData(bytes, name: name, mimeType: mime);
    final resolvedSubject = (shareSubject ?? _exportShareSubject(name)).trim();
    final resolvedText = (shareText ?? _exportShareText(name)).trim();

    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (share) {
      if (kIsWeb) {
        final shared = await _tryShareWebFile(
          xf,
          subject: resolvedSubject,
          text: resolvedText,
          shouldCancel: shouldCancel,
        );
        if (shared) {
          return _buildShareOpenedExportFlowResult(
            name: name,
            includeAttachments: includeAttachments,
          );
        }
        _throwIfOperationCancelledBy(shouldCancel);
        await _saveExportFileTo(xf, name);
        return _buildDownloadStartedExportFlowResult(
          name: name,
          shareRequested: true,
          includeAttachments: includeAttachments,
          message: _isIosWeb
              ? 'Safari en iPhone limita compartir archivos desde esta pantalla. ${EditorExportOutcomeFactory.downloadStarted(name: name, shareRequested: true, includeAttachments: includeAttachments).message} Abrilo desde Descargas y usa Compartir.'
              : 'Este navegador no permite compartir archivos directamente. ${EditorExportOutcomeFactory.downloadStarted(name: name, shareRequested: true, includeAttachments: includeAttachments).message}',
        );
      }

      if (isMobile) {
        final shared = await _shareOnMobileWithFallbacks(
          name: name,
          mime: mime,
          bytes: bytes,
          shouldCancel: shouldCancel,
          subject: resolvedSubject,
          text: resolvedText,
        );
        if (shared) {
          return _buildShareOpenedExportFlowResult(
            name: name,
            includeAttachments: includeAttachments,
          );
        }
      }
    }

    if (kIsWeb) {
      try {
        _throwIfOperationCancelledBy(shouldCancel);
        await _saveExportFileTo(xf, name);
        if (share) {
          return _buildDownloadStartedExportFlowResult(
            name: name,
            shareRequested: true,
            includeAttachments: includeAttachments,
            message:
                'No pudimos abrir compartir. ${EditorExportOutcomeFactory.downloadStarted(name: name, shareRequested: true, includeAttachments: includeAttachments).message}',
          );
        } else {
          return _buildDownloadStartedExportFlowResult(
            name: name,
            shareRequested: false,
            includeAttachments: includeAttachments,
          );
        }
      } catch (_) {}
    }

    if (isMobile) {
      try {
        _throwIfOperationCancelledBy(shouldCancel);
        await _shareExportParamsSafely(
          params: ShareParams(
            files: [xf],
            subject: resolvedSubject,
            text: resolvedText,
          ),
          operation: 'share_mobile_direct',
          shouldCancel: shouldCancel,
        );
        if (share) {
          return _buildShareOpenedExportFlowResult(
            name: name,
            includeAttachments: includeAttachments,
          );
        } else {
          return _buildSystemSheetOpenedExportFlowResult(
            name: name,
            includeAttachments: includeAttachments,
          );
        }
      } catch (e) {
        if (_looksLikeShareUserCancel(e)) {
          throw const _EditorLongOperationCancelled();
        }
        if (e is TimeoutException) {
          rethrow;
        }
      }
    }

    final lower = name.toLowerCase();
    final extensions = lower.endsWith('.zip')
        ? const ['zip']
        : lower.endsWith('.pdf')
            ? const ['pdf']
            : (lower.endsWith('.html') || lower.endsWith('.htm'))
                ? const ['html', 'htm']
                : const ['xlsx'];
    final typeGroup = XTypeGroup(label: 'Exportar', extensions: extensions);
    _throwIfOperationCancelledBy(shouldCancel);
    final loc = await _pickExportSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [typeGroup],
    );
    if (loc == null) {
      throw const _EditorLongOperationCancelled();
    }
    _throwIfOperationCancelledBy(shouldCancel);
    await _saveExportFileTo(xf, loc.path);
    return _buildSavedExportFlowResult(
      name: name,
      shareRequested: share,
      includeAttachments: includeAttachments,
      savedPath: loc.path,
    );
  }

  Future<bool> _tryShareWebFile(
    XFile file, {
    required String subject,
    required String text,
    bool Function()? shouldCancel,
  }) async {
    try {
      await _shareExportParamsSafely(
        params: ShareParams(
          files: [file],
          subject: subject,
          text: text,
        ),
        operation: 'share_web',
        shouldCancel: shouldCancel,
      );
      return true;
    } catch (e) {
      if (_looksLikeShareUserCancel(e)) {
        throw const _EditorLongOperationCancelled();
      }
      if (e is TimeoutException) {
        rethrow;
      }
      return false;
    }
  }

  Future<bool> _shareOnMobileWithFallbacks({
    required String name,
    required String mime,
    required Uint8List bytes,
    required String subject,
    required String text,
    bool Function()? shouldCancel,
  }) async {
    final path =
        await _persistShareExportTempFile(fileName: name, bytes: bytes);

    if (path != null && path.trim().isNotEmpty) {
      try {
        _throwIfOperationCancelledBy(shouldCancel);
        await _shareExportParamsSafely(
          params: ShareParams(
            files: <XFile>[XFile(path, mimeType: mime, name: name)],
            subject: subject,
            text: text,
          ),
          operation: 'share_mobile_temp_mime',
          shouldCancel: shouldCancel,
        );
        return true;
      } catch (e) {
        if (_looksLikeShareUserCancel(e)) {
          throw const _EditorLongOperationCancelled();
        }
        if (e is TimeoutException) {
          rethrow;
        }
      }

      try {
        _throwIfOperationCancelledBy(shouldCancel);
        await _shareExportParamsSafely(
          params: ShareParams(
            files: <XFile>[XFile(path, name: name)],
            subject: subject,
            text: text,
          ),
          operation: 'share_mobile_temp_plain',
          shouldCancel: shouldCancel,
        );
        return true;
      } catch (e) {
        if (_looksLikeShareUserCancel(e)) {
          throw const _EditorLongOperationCancelled();
        }
        if (e is TimeoutException) {
          rethrow;
        }
      }

      try {
        _throwIfOperationCancelledBy(shouldCancel);
        final email = Email(
          subject: subject,
          body: text,
          attachmentPaths: <String>[path],
          isHTML: false,
        );
        await FlutterEmailSender.send(email);
        return true;
      } catch (_) {}

      try {
        _throwIfOperationCancelledBy(shouldCancel);
        final mailto = Uri(
          scheme: 'mailto',
          queryParameters: <String, String>{
            'subject': subject,
            'body': '$text\n\nRuta local del archivo:\n$path',
          },
        );
        if (await canLaunchUrl(mailto)) {
          final launched = await launchUrl(
            mailto,
            mode: LaunchMode.externalApplication,
          );
          if (launched) {
            return true;
          }
        }
      } catch (_) {}
    }

    try {
      _throwIfOperationCancelledBy(shouldCancel);
      await _shareExportParamsSafely(
        params: ShareParams(
          files: <XFile>[XFile.fromData(bytes, name: name, mimeType: mime)],
          subject: subject,
          text: text,
        ),
        operation: 'share_mobile_memory',
        shouldCancel: shouldCancel,
      );
      return true;
    } catch (e) {
      if (_looksLikeShareUserCancel(e)) {
        throw const _EditorLongOperationCancelled();
      }
      if (e is TimeoutException) {
        rethrow;
      }
      return false;
    }
  }

  bool _looksLikeShareUserCancel(Object error) {
    final lower = error.toString().toLowerCase();
    return lower.contains('aborterror') ||
        lower.contains('user aborted') ||
        lower.contains('aborted by user') ||
        lower.contains('share canceled') ||
        lower.contains('share cancelled') ||
        lower.contains('cancelled') ||
        lower.contains('canceled') ||
        lower.contains('dismissed') ||
        lower.contains('did not share');
  }
}
