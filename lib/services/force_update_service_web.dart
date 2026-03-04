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
        if (regs.isNotEmpty) {
          await Future.wait(regs.map((reg) => reg.unregister()));
          messages.add('Service Worker eliminado (${regs.length}).');
        } else {
          messages.add('Service Worker sin registros activos.');
        }
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
        if (keys.isNotEmpty) {
          await Future.wait(keys.map((key) => caches.delete(key)));
          messages.add('Caches limpiados (${keys.length}).');
        } else {
          messages.add('CacheStorage sin entradas activas.');
        }
      } else {
        messages.add('CacheStorage no disponible.');
      }
    } catch (e) {
      messages.add('Error limpiando caches: $e');
    }

    // Forzar reload con cache-busting por pathname.
    try {
      final bust = DateTime.now().millisecondsSinceEpoch;
      final pathname = html.window.location.pathname ?? '/';
      html.window.location.href = '$pathname?v=$bust';
      messages.add('Recarga solicitada.');
    } catch (_) {}

    return ForceUpdateResult(
      supported: true,
      reloaded: true,
      message: messages.join('\n'),
    );
  }
}
