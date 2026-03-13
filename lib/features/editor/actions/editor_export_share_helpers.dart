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
      '${_formatLabelFromFileName(name)} guardado: $label';

  String _downloadStartedMessage(String name) =>
      'Descarga de ${_formatLabelFromFileName(name)} iniciada: $name';

  String _shareOpenedMessage(String name) =>
      '${_formatLabelFromFileName(name)} listo para compartir: $name';

  String _exportSheetOpenedMessage(String name) =>
      '${_formatLabelFromFileName(name)} listo para guardar o enviar: $name. El sistema abrió las opciones para compartir.';

  String _shareFallbackSavedMessage({
    required String name,
    String? location,
  }) {
    final target = (location ?? '').trim().isEmpty ? name : location!.trim();
    return 'No pudimos abrir la opción de compartir el ${_formatLabelFromFileName(name)}. El archivo ya quedó listo para guardar o enviar: $target';
  }

  String _formatLabelFromFileName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.xlsx')) return 'XLSX';
    if (lower.endsWith('.pdf')) return 'PDF';
    if (lower.endsWith('.zip')) return 'paquete ZIP';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'HTML';
    return 'archivo';
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

  Future<void> _saveExportBytes({
    required String name,
    required String mime,
    required Uint8List bytes,
    required bool share,
    bool Function()? shouldCancel,
    String? successMessage,
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

    void notifySuccess([String? overrideMessage]) {
      final msg = (overrideMessage ?? successMessage ?? '').trim();
      if (msg.isEmpty || !mounted) return;
      _showActionSnack(
        msg,
        isError: false,
        icon: share ? Icons.ios_share_rounded : Icons.download_done_rounded,
      );
    }

    void notifySavedFallbackFromShare([String? location]) {
      if (!mounted) return;
      _showActionSnack(
        _shareFallbackSavedMessage(name: name, location: location),
        isError: false,
        icon: Icons.save_alt_rounded,
      );
    }

    if (share) {
      if (kIsWeb) {
        final shared = await _tryShareWebFile(
          xf,
          subject: resolvedSubject,
          text: resolvedText,
        );
        if (shared) {
          notifySuccess(_shareOpenedMessage(name));
          return;
        }
        _throwIfOperationCancelledBy(shouldCancel);
        await _saveExportFileTo(xf, name);
        if (!mounted) return;
        _showActionSnack(
          _isIosWeb
              ? 'Safari en iPhone limita compartir archivos desde esta pantalla. ${_downloadStartedMessage(name)} Abrilo desde Descargas y usa Compartir.'
              : 'Este navegador no permite compartir archivos directamente. ${_downloadStartedMessage(name)}',
          isError: false,
          icon: Icons.download_rounded,
        );
        return;
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
          notifySuccess();
          return;
        }
      }
    }

    if (kIsWeb) {
      try {
        _throwIfOperationCancelledBy(shouldCancel);
        await _saveExportFileTo(xf, name);
        if (share) {
          notifySavedFallbackFromShare(name);
        } else {
          notifySuccess(_downloadStartedMessage(name));
        }
        return;
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
          notifySuccess(_shareOpenedMessage(name));
        } else if (mounted) {
          _showActionSnack(
            _exportSheetOpenedMessage(name),
            isError: false,
            icon: Icons.ios_share_rounded,
          );
        }
        return;
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
    final savedLocation = _describeExportSaveLocation(loc.path);
    if (share) {
      notifySavedFallbackFromShare(savedLocation);
    } else {
      notifySuccess(
        _fileReadyMessage(
          savedLocation.isEmpty ? name : savedLocation,
          name: name,
        ),
      );
    }
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
