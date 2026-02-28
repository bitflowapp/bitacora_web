import 'dart:async';
import 'package:bitacora_web/web/html_compat.dart' as html;

import 'force_update_service.dart';

class ForceUpdateServiceImpl implements ForceUpdateService {
  @override
  Future<ForceUpdateResult> forceUpdate() async {
    final messages = <String>[];
    try {
      final sw = html.window.navigator.serviceWorker;
      if (sw != null) {
        final regs = await sw.getRegistrations();
        for (final reg in regs) {
          await reg.unregister();
        }
        messages.add('Service Worker eliminado.');
      } else {
        messages.add('Service Worker no disponible.');
      }
    } catch (e) {
      messages.add('Error al remover Service Worker: $e');
    }

    try {
      final caches = html.window.caches;
      if (caches != null) {
        final keys = await caches.keys();
        for (final key in keys) {
          await caches.delete(key);
        }
        messages.add('Caches limpiados.');
      } else {
        messages.add('CacheStorage no disponible.');
      }
    } catch (e) {
      messages.add('Error limpiando caches: $e');
    }

    // Forzar reload con cache-busting
    try {
      final uri = html.window.location;
      final base = uri.href.split('#').first;
      final bust = DateTime.now().millisecondsSinceEpoch;
      html.window.location.replace('$base?reload=$bust');
    } catch (_) {}

    return ForceUpdateResult(
      supported: true,
      reloaded: true,
      message: messages.join('\n'),
    );
  }
}
