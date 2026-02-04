import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../services/audio_service.dart';
import '../services/audio_storage_service.dart';
import '../services/build_info.dart';
import '../services/diagnostics_log.dart';
import '../services/force_update_service.dart';
import '../services/photo_acquire_service.dart';
import '../services/photo_storage_service.dart';
import '../services/storage_diagnostics.dart';
import '../services/web_capabilities.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late Future<_DiagnosticsSnapshot> _future;
  String? _photoTestResult;
  String? _audioTestResult;
  bool _photoTestBusy = false;
  bool _audioTestBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DiagnosticsSnapshot> _load() async {
    final isSecure = kIsWeb ? WebCapabilities.isSecureContext : true;
    final geoAvailable = kIsWeb
        ? WebCapabilities.geolocationAvailable
        : await _safeGeoEnabled();

    final geoPerm = await _safeGeoPermission();

    final audio = AudioService.I;
    final micSupported = await _safeBool(audio.isSupported());
    final micPerm = await _safeBool(audio.hasPermission());
    await audio.dispose();

    final storage = await StorageDiagnostics.check();
    final versionJson = await _safeLoadVersion();

    final mediaRecorderSupported =
        kIsWeb ? WebCapabilities.mediaRecorderSupported : false;
    final cameraAvailable =
        kIsWeb ? WebCapabilities.cameraAvailable : false;
    final imageCaptureSupported =
        kIsWeb ? WebCapabilities.imageCaptureSupported : false;
    final serviceWorkerSupported =
        kIsWeb ? WebCapabilities.serviceWorkerSupported : false;
    final indexedDbAvailable = kIsWeb ? WebCapabilities.indexedDbAvailable : false;
    final inAppBrowser = kIsWeb ? WebCapabilities.isInAppBrowser : false;

    return _DiagnosticsSnapshot(
      isSecureContext: isSecure,
      geolocationAvailable: geoAvailable,
      geolocationPermission: geoPerm,
      micSupported: micSupported,
      micPermission: micPerm,
      mediaRecorderSupported: mediaRecorderSupported,
      cameraAvailable: cameraAvailable,
      imageCaptureSupported: imageCaptureSupported,
      storageOk: storage.ok,
      storageMessage: storage.message,
      serviceWorkerSupported: serviceWorkerSupported,
      indexedDbAvailable: indexedDbAvailable,
      inAppBrowser: inAppBrowser,
      versionJson: versionJson,
    );
  }

  Future<bool> _safeBool(Future<bool> f) async {
    try {
      return await f;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _safeGeoEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<String> _safeLoadVersion() async {
    try {
      final raw = await rootBundle.loadString('assets/version.json');
      return raw.trim().isEmpty ? BuildInfo.toJsonString() : raw.trim();
    } catch (_) {
      return BuildInfo.toJsonString();
    }
  }

  Future<LocationPermission> _safeGeoPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  void _recheckPermissions() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _showPermissionHelp() async {
    if (!mounted) return;
    if (kIsWeb) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Abrir ajustes del navegador'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Para GPS/Microfono, abrí los ajustes del navegador y habilitá permisos para este sitio.',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final opened = await Geolocator.openAppSettings();
      if (!opened) {
        await Geolocator.openLocationSettings();
      }
    } catch (_) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Abrir ajustes'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No se pudieron abrir los ajustes en este dispositivo.'),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  String _permLabel(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
        return 'always';
      case LocationPermission.whileInUse:
        return 'whileInUse';
      case LocationPermission.denied:
        return 'denied';
      case LocationPermission.deniedForever:
        return 'deniedForever';
      case LocationPermission.unableToDetermine:
        return 'unknown';
    }
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _forceUpdate() async {
    final res = await ForceUpdateService.I.forceUpdate();
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Forzar actualizacion'),
        content: Text(res.message.trim().isEmpty
            ? 'Operación completada.'
            : res.message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _fmtBytes(int bytes) {
    const kb = 1024;
    const mb = 1024 * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  Future<void> _runPhotoSelfTest() async {
    if (_photoTestBusy) return;
    if (!kIsWeb) {
      setState(() => _photoTestResult = 'Solo disponible en Web.');
      return;
    }
    setState(() {
      _photoTestBusy = true;
      _photoTestResult = 'Abriendo camara...';
    });

    try {
      final outcome = await PhotoAcquireService.I.captureFromCamera(context: context);
      if (!mounted) return;
      if (outcome.cancelled) {
        setState(() => _photoTestResult = 'cancelled');
        return;
      }
      if (outcome.blocked) {
        setState(() => _photoTestResult = 'blocked: ${outcome.error}');
        return;
      }
      if (!outcome.ok) {
        setState(() => _photoTestResult = 'error: ${outcome.error}');
        return;
      }
      final result = outcome.result!;
      final sizeLabel = _fmtBytes(result.bytes.lengthInBytes);
      final stored = await PhotoStorageService.I.savePhoto(
        sheetId: 'diagnostics',
        cellKey: 'selftest',
        attachmentId: 'photo_${DateTime.now().microsecondsSinceEpoch}',
        bytes: result.bytes,
        originalName: result.name,
        mime: result.mime,
      );
      final storageLabel = stored == null
          ? 'FAIL'
          : (stored.path.startsWith('mem:') ? 'RAM' : 'OK');
      final read = stored == null
          ? null
          : await PhotoStorageService.I.readPhotoBytes(stored.path);
      final readOk = read != null && read.isNotEmpty ? 'OK' : 'FAIL';
      setState(() {
        _photoTestResult =
            'picked $sizeLabel · storage $storageLabel · read $readOk';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _photoTestResult = 'error: $e');
    } finally {
      if (mounted) setState(() => _photoTestBusy = false);
    }
  }

  Future<void> _runAudioSelfTest() async {
    if (_audioTestBusy) return;
    if (!kIsWeb) {
      setState(() => _audioTestResult = 'Solo disponible en Web.');
      return;
    }
    setState(() {
      _audioTestBusy = true;
      _audioTestResult = 'Grabando 2s...';
    });

    final audio = AudioService.I;
    try {
      await audio.startRecording(sheetId: 'diagnostics');
      await Future.delayed(const Duration(seconds: 2));
      final recording = await audio.stopRecording();
      if (recording == null || recording.bytes == null) {
        setState(() => _audioTestResult = 'error: audio vacio.');
        return;
      }
      final sizeLabel = _fmtBytes(recording.bytes!.lengthInBytes);
      final stored = await AudioStorageService.I.saveRecording(
        sheetId: 'diagnostics',
        cellKey: 'selftest',
        attachmentId: 'audio_${DateTime.now().microsecondsSinceEpoch}',
        recording: recording,
      );
      final storageLabel = stored == null
          ? 'FAIL'
          : (stored.storageKey.startsWith('mem:') ? 'RAM' : 'OK');
      final read = stored == null
          ? null
          : await AudioStorageService.I.readAudioBytes(stored.storageKey);
      final readOk = read != null && read.isNotEmpty ? 'OK' : 'FAIL';
      setState(() {
        _audioTestResult =
            'picked $sizeLabel · storage $storageLabel · read $readOk';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _audioTestResult = 'error: $e');
    } finally {
      try {
        await audio.dispose();
      } catch (_) {}
      if (mounted) setState(() => _audioTestBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Diagnósticos'),
      ),
      child: SafeArea(
        child: FutureBuilder<_DiagnosticsSnapshot>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }
            final data = snap.data ?? _DiagnosticsSnapshot.empty();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _sectionTitle('Build'),
                _infoCard(
                  children: [
                    _infoRow('Stamp', BuildInfo.stamp),
                    _infoRow('GIT_SHA', BuildInfo.gitSha.isEmpty ? 'dev' : BuildInfo.gitSha),
                    _infoRow('BUILD_TIME', BuildInfo.buildTime.isEmpty ? 'dev' : BuildInfo.buildTime),
                    _infoRow('ENGINE_BASE_URL', BuildInfo.engineBaseUrl.isEmpty ? 'vacio' : BuildInfo.engineBaseUrl),
                    const SizedBox(height: 8),
                    CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      onPressed: _forceUpdate,
                      child: const Text('Forzar actualizacion'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionTitle('Permisos/Capacidades'),
                _infoCard(
                  children: [
                    _checkRow('Secure context (HTTPS)', data.isSecureContext),
                    _checkRow('Geolocation disponible', data.geolocationAvailable),
                    _infoRow('Geo permiso', _permLabel(data.geolocationPermission)),
                    _checkRow('Microfono soportado', data.micSupported),
                    _infoRow('Mic permiso', data.micPermission ? 'granted' : 'denied'),
                    if (kIsWeb)
                      _checkRow('MediaRecorder soportado', data.mediaRecorderSupported),
                    if (kIsWeb)
                      _checkRow('getUserMedia disponible', data.cameraAvailable),
                    if (kIsWeb)
                      _checkRow('ImageCapture soportado', data.imageCaptureSupported),
                    if (kIsWeb)
                      _checkRow('Service Worker soportado', data.serviceWorkerSupported),
                    if (kIsWeb)
                      _checkRow('IndexedDB disponible', data.indexedDbAvailable),
                    _checkRow('Storage writable', data.storageOk,
                        message: data.storageMessage),
                    if (kIsWeb)
                      _checkRow('Navegador embebido', !data.inAppBrowser,
                          message: data.inAppBrowser ? 'Detectado' : 'OK'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            onPressed: _recheckPermissions,
                            child: const Text('Re-chequear permisos'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            onPressed: _showPermissionHelp,
                            child: const Text('Abrir ajustes'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionTitle('Ultima accion'),
                _infoCard(
                  children: [
                    ValueListenableBuilder<DiagnosticEvent?>(
                      valueListenable: DiagnosticsLog.I.lastEvent,
                      builder: (ctx, ev, _) {
                        if (ev == null) {
                          return _infoRow('Estado', 'Sin acciones registradas');
                        }
                        final type = ev.type.name.toUpperCase();
                        final status = ev.ok ? 'OK' : 'ERROR';
                        final time = _fmtTime(ev.at);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoRow('Accion', '$type - $status - $time'),
                            if (ev.message.trim().isNotEmpty)
                              _infoRow('Detalle', ev.message),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionTitle('Self test (Web)'),
                _infoCard(
                  children: [
                    _infoRow('Foto', _photoTestResult ?? 'Sin ejecutar'),
                    const SizedBox(height: 6),
                    CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      onPressed: _photoTestBusy ? null : _runPhotoSelfTest,
                      child: Text(
                        _photoTestBusy
                            ? 'Probando...'
                            : 'Self-test Foto (web)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _infoRow('Audio', _audioTestResult ?? 'Sin ejecutar'),
                    const SizedBox(height: 6),
                    CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      onPressed: _audioTestBusy ? null : _runAudioSelfTest,
                      child: Text(_audioTestBusy ? 'Probando...' : 'Test Audio'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionTitle('Version JSON (asset)'),
                _infoCard(
                  children: [
                    _infoRow('version.json', data.versionJson),
                    const SizedBox(height: 6),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: data.versionJson),
                        );
                      },
                      child: const Text('Copiar JSON'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle('Si ves version vieja'),
                _infoCard(
                  children: const [
                    Text(
                      'Chrome: DevTools ? Application ? Service Workers ? Unregister + Clear site data + hard reload.\n'
                      'iOS Safari: Ajustes ? Safari ? Avanzado ? Datos de sitios web ? borrar el dominio.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey4),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkRow(String label, bool ok, {String message = ''}) {
    final color = ok ? CupertinoColors.activeGreen : CupertinoColors.systemRed;
    final text = message.trim().isEmpty ? (ok ? 'OK' : 'NO') : message;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? CupertinoIcons.check_mark : CupertinoIcons.xmark, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label - $text',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSnapshot {
  const _DiagnosticsSnapshot({
    required this.isSecureContext,
    required this.geolocationAvailable,
    required this.geolocationPermission,
    required this.micSupported,
    required this.micPermission,
    required this.mediaRecorderSupported,
    required this.cameraAvailable,
    required this.imageCaptureSupported,
    required this.storageOk,
    required this.storageMessage,
    required this.serviceWorkerSupported,
    required this.indexedDbAvailable,
    required this.inAppBrowser,
    required this.versionJson,
  });

  final bool isSecureContext;
  final bool geolocationAvailable;
  final LocationPermission geolocationPermission;
  final bool micSupported;
  final bool micPermission;
  final bool mediaRecorderSupported;
  final bool cameraAvailable;
  final bool imageCaptureSupported;
  final bool storageOk;
  final String storageMessage;
  final bool serviceWorkerSupported;
  final bool indexedDbAvailable;
  final bool inAppBrowser;
  final String versionJson;

  factory _DiagnosticsSnapshot.empty() => _DiagnosticsSnapshot(
        isSecureContext: false,
        geolocationAvailable: false,
        geolocationPermission: LocationPermission.denied,
        micSupported: false,
        micPermission: false,
        mediaRecorderSupported: false,
        cameraAvailable: false,
        imageCaptureSupported: false,
        storageOk: false,
        storageMessage: 'Sin datos',
        serviceWorkerSupported: false,
        indexedDbAvailable: false,
        inAppBrowser: false,
        versionJson: 'Sin datos',
      );
}







