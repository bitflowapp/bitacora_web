import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../services/audio_service.dart';
import '../services/build_info.dart';
import '../services/diagnostics_log.dart';
import '../services/force_update_service.dart';
import '../services/storage_diagnostics.dart';
import '../services/web_capabilities.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late Future<_DiagnosticsSnapshot> _future;

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
    final serviceWorkerSupported =
        kIsWeb ? WebCapabilities.serviceWorkerSupported : false;
    final indexedDbAvailable = kIsWeb ? WebCapabilities.indexedDbAvailable : false;

    return _DiagnosticsSnapshot(
      isSecureContext: isSecure,
      geolocationAvailable: geoAvailable,
      geolocationPermission: geoPerm,
      micSupported: micSupported,
      micPermission: micPerm,
      mediaRecorderSupported: mediaRecorderSupported,
      storageOk: storage.ok,
      storageMessage: storage.message,
      serviceWorkerSupported: serviceWorkerSupported,
      indexedDbAvailable: indexedDbAvailable,
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
        title: const Text('Forzar actualización'),
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
                    _infoRow('ENGINE_BASE_URL', BuildInfo.engineBaseUrl.isEmpty ? 'vacío' : BuildInfo.engineBaseUrl),
                    const SizedBox(height: 8),
                    CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      onPressed: _forceUpdate,
                      child: const Text('Forzar actualización'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionTitle('Checks'),
                _infoCard(
                  children: [
                    _checkRow('Secure context (HTTPS)', data.isSecureContext),
                    _checkRow('Geolocation disponible', data.geolocationAvailable),
                    _infoRow('Geo permiso', _permLabel(data.geolocationPermission)),
                    _checkRow('Micrófono soportado', data.micSupported),
                    _infoRow('Mic permiso', data.micPermission ? 'granted' : 'denied'),
                    if (kIsWeb)
                      _checkRow('MediaRecorder soportado', data.mediaRecorderSupported),
                    if (kIsWeb)
                      _checkRow('Service Worker soportado', data.serviceWorkerSupported),
                    if (kIsWeb)
                      _checkRow('IndexedDB disponible', data.indexedDbAvailable),
                    _checkRow('Storage writable', data.storageOk,
                        message: data.storageMessage),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionTitle('Última acción'),
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
                            _infoRow('Acción', '$type  $status  $time'),
                            if (ev.message.trim().isNotEmpty)
                              _infoRow('Detalle', ev.message),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionTitle('Versión JSON (asset)'),
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
                _sectionTitle('Si ves versión vieja'),
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
              '$label  $text',
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
    required this.storageOk,
    required this.storageMessage,
    required this.serviceWorkerSupported,
    required this.indexedDbAvailable,
    required this.versionJson,
  });

  final bool isSecureContext;
  final bool geolocationAvailable;
  final LocationPermission geolocationPermission;
  final bool micSupported;
  final bool micPermission;
  final bool mediaRecorderSupported;
  final bool storageOk;
  final String storageMessage;
  final bool serviceWorkerSupported;
  final bool indexedDbAvailable;
  final String versionJson;

  factory _DiagnosticsSnapshot.empty() => _DiagnosticsSnapshot(
        isSecureContext: false,
        geolocationAvailable: false,
        geolocationPermission: LocationPermission.denied,
        micSupported: false,
        micPermission: false,
        mediaRecorderSupported: false,
        storageOk: false,
        storageMessage: 'Sin datos',
        serviceWorkerSupported: false,
        indexedDbAvailable: false,
        versionJson: 'Sin datos',
      );
}
