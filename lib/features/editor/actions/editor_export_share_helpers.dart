part of '../editor_screen.dart';

extension _EditorExportShareHelpers on _EditorScreenState {
  String _describeExportSaveLocation(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= 72) return trimmed;
    final parts = trimmed.split(RegExp(r'[\\/]'));
    if (parts.length < 2) return trimmed;
    return '.../${parts[parts.length - 2]}/${parts.last}';
  }

  String _exportShareSubject(String name) =>
      'BitFlow | ${_formatLabelFromFileName(name)} | $name';

  String _exportShareText(String name) =>
      '${_formatLabelFromFileName(name)} exportado desde BitFlow: $name';

  String _fileReadyMessage(String label, {required String name}) =>
      switch (_exportMessageKind(name)) {
        _ExportMessageKind.pdf => 'PDF guardado en $label',
        _ExportMessageKind.zip =>
          'Paquete ZIP guardado en $label. Incluye planilla y evidencias.',
        _ExportMessageKind.xlsx => 'Excel guardado en $label',
        _ExportMessageKind.other => 'Archivo guardado en $label',
      };

  String _downloadStartedMessage(String name) =>
      switch (_exportMessageKind(name)) {
        _ExportMessageKind.pdf => 'Descarga iniciada: $name. Revisa Descargas.',
        _ExportMessageKind.zip =>
          'Descarga iniciada: $name. Revisa Descargas. Incluye planilla y evidencias.',
        _ExportMessageKind.xlsx =>
          'Descarga iniciada: $name. Revisa Descargas.',
        _ExportMessageKind.other =>
          'Descarga iniciada: $name. Revisa Descargas.',
      };

  String _shareOpenedMessage(String name) => switch (_exportMessageKind(name)) {
        _ExportMessageKind.pdf =>
          'Abrimos compartir para $name. Completa el envio para terminar.',
        _ExportMessageKind.zip =>
          'Abrimos compartir para $name. Completa el envio para terminar.',
        _ExportMessageKind.xlsx =>
          'Abrimos compartir para $name. Completa el envio para terminar.',
        _ExportMessageKind.other =>
          'Abrimos compartir para $name. Completa el envio para terminar.',
      };

  String _exportSheetOpenedMessage(String name) =>
      switch (_exportMessageKind(name)) {
        _ExportMessageKind.pdf =>
          'Abrimos las opciones del sistema para guardar o compartir $name. Completa ese paso para terminar.',
        _ExportMessageKind.zip =>
          'Abrimos las opciones del sistema para guardar o compartir $name. Completa ese paso para terminar.',
        _ExportMessageKind.xlsx =>
          'Abrimos las opciones del sistema para guardar o compartir $name. Completa ese paso para terminar.',
        _ExportMessageKind.other =>
          'Abrimos las opciones del sistema para guardar o compartir $name. Completa ese paso para terminar.',
      };

  String _shareFallbackSavedMessage({
    required String name,
    String? location,
  }) {
    final target = (location ?? '').trim().isEmpty ? name : location!.trim();
    return 'No pudimos abrir compartir. Guardamos $name en $target.';
  }

  _ExportFlowResult _buildSavedExportFlowResult({
    required String name,
    required bool shareRequested,
    required bool includeAttachments,
    String? savedPath,
  }) {
    final path = (savedPath ?? '').trim();
    final label = path.isEmpty ? name : _describeExportSaveLocation(path);
    final message = shareRequested
        ? _shareFallbackSavedMessage(name: name, location: label)
        : _fileReadyMessage(label.isEmpty ? name : label, name: name);
    return _createExportFlowResult(
      kind: _ExportFlowResultKind.saved,
      fileName: name,
      format: _exportFormatFromFileName(name),
      message: message,
      savedPath: path.isEmpty ? null : path,
      shareRequested: shareRequested,
      includeAttachments: includeAttachments,
    );
  }

  _ExportFlowResult _buildDownloadStartedExportFlowResult({
    required String name,
    required bool shareRequested,
    required bool includeAttachments,
    String? message,
  }) {
    final resolvedMessage = (message ?? '').trim().isEmpty
        ? _downloadStartedMessage(name)
        : message!.trim();
    return _createExportFlowResult(
      kind: _ExportFlowResultKind.downloadStarted,
      fileName: name,
      format: _exportFormatFromFileName(name),
      message: resolvedMessage,
      shareRequested: shareRequested,
      includeAttachments: includeAttachments,
    );
  }

  _ExportFlowResult _buildShareOpenedExportFlowResult({
    required String name,
    required bool includeAttachments,
    String? message,
  }) {
    final resolvedMessage = (message ?? '').trim().isEmpty
        ? _shareOpenedMessage(name)
        : message!.trim();
    return _createExportFlowResult(
      kind: _ExportFlowResultKind.shareOpened,
      fileName: name,
      format: _exportFormatFromFileName(name),
      message: resolvedMessage,
      shareRequested: true,
      includeAttachments: includeAttachments,
    );
  }

  _ExportFlowResult _buildSystemSheetOpenedExportFlowResult({
    required String name,
    required bool includeAttachments,
  }) {
    return _createExportFlowResult(
      kind: _ExportFlowResultKind.systemSheetOpened,
      fileName: name,
      format: _exportFormatFromFileName(name),
      message: _exportSheetOpenedMessage(name),
      shareRequested: false,
      includeAttachments: includeAttachments,
    );
  }

  String _formatLabelFromFileName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.xlsx')) return 'XLSX';
    if (lower.endsWith('.pdf')) return 'PDF';
    if (lower.endsWith('.zip')) return 'paquete ZIP';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'HTML';
    return 'archivo';
  }

  _ExportMessageKind _exportMessageKind(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return _ExportMessageKind.pdf;
    if (lower.endsWith('.zip')) return _ExportMessageKind.zip;
    if (lower.endsWith('.xlsx')) return _ExportMessageKind.xlsx;
    return _ExportMessageKind.other;
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

  Future<_ExportFlowResult> _saveExportBytes({
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
              ? 'Safari en iPhone limita compartir archivos desde esta pantalla. ${_downloadStartedMessage(name)} Abrilo desde Descargas y usa Compartir.'
              : 'Este navegador no permite compartir archivos directamente. ${_downloadStartedMessage(name)}',
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
                'No pudimos abrir compartir. ${_downloadStartedMessage(name)}',
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
        await _shareExportParams(
          ShareParams(
            files: [xf],
            subject: resolvedSubject,
            text: resolvedText,
          ),
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
  }) async {
    try {
      await _shareExportParams(
        ShareParams(
          files: [file],
          subject: subject,
          text: text,
        ),
      );
      return true;
    } catch (e) {
      if (_looksLikeShareUserCancel(e)) {
        throw const _EditorLongOperationCancelled();
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
        await _shareExportParams(
          ShareParams(
            files: <XFile>[XFile(path, mimeType: mime, name: name)],
            subject: subject,
            text: text,
          ),
        );
        return true;
      } catch (e) {
        if (_looksLikeShareUserCancel(e)) {
          throw const _EditorLongOperationCancelled();
        }
      }

      try {
        _throwIfOperationCancelledBy(shouldCancel);
        await _shareExportParams(
          ShareParams(
            files: <XFile>[XFile(path, name: name)],
            subject: subject,
            text: text,
          ),
        );
        return true;
      } catch (e) {
        if (_looksLikeShareUserCancel(e)) {
          throw const _EditorLongOperationCancelled();
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
          await launchUrl(mailto, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}
    }

    try {
      _throwIfOperationCancelledBy(shouldCancel);
      await _shareExportParams(
        ShareParams(
          files: <XFile>[XFile.fromData(bytes, name: name, mimeType: mime)],
          subject: subject,
          text: text,
        ),
      );
      return true;
    } catch (e) {
      if (_looksLikeShareUserCancel(e)) {
        throw const _EditorLongOperationCancelled();
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

enum _ExportMessageKind { xlsx, pdf, zip, other }
