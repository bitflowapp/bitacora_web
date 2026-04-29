import 'dart:async';

import 'package:bitacora_web/web/html_compat.dart' as html;

import 'force_update_service.dart';

class ForceUpdateServiceImpl implements ForceUpdateService {
  @override
  Future<bool> hasWebCacheArtifacts() async {
    try {
      final sw = html.window.navigator.serviceWorker;
      if (sw != null) {
        final regs = await sw.getRegistrations();
        if (regs.isNotEmpty) return true;
      }
    } catch (_) {}

    try {
      final caches = html.window.caches;
      if (caches != null) {
        final keys = await caches.keys();
        if (keys.isNotEmpty) return true;
      }
    } catch (_) {}

    return false;
  }

  @override
  Future<void> reloadWithCacheBust(String cacheBustValue) async {
    final raw = cacheBustValue.trim();
    final bust =
        raw.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : raw;
    final path = html.window.location.pathname ?? '/';
    html.window.location.href = '$path?v=${Uri.encodeQueryComponent(bust)}';
  }

  @override
  Future<ForceUpdateResult> forceUpdate({String? cacheBustValue}) async {
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

    try {
      await reloadWithCacheBust(cacheBustValue ?? '');
      messages.add('Recarga solicitada.');
    } catch (_) {}

    return ForceUpdateResult(
      supported: true,
      reloaded: true,
      message: messages.join('\n'),
    );
  }
}
