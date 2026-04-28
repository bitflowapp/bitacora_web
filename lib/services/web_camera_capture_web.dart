import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';

import 'diagnostics_log.dart';
import 'web_camera_capture_types.dart';
import 'web_camera_overlay.dart';
import 'web_capabilities.dart';

Future<WebCameraCaptureResult> captureFromWebCamera({
  required BuildContext context,
  double jpegQuality = 0.9,
}) async {
  void log(String msg, {bool ok = true}) {
    DiagnosticsLog.I.record(
      type: DiagnosticActionType.photo,
      ok: ok,
      message: msg,
    );
  }

  final ua = html.window.navigator.userAgent;
  final uaLower = ua.toLowerCase();
  final isIOS = uaLower.contains('iphone') ||
      uaLower.contains('ipad') ||
      uaLower.contains('ipod');
  final isSafari = uaLower.contains('safari') &&
      !uaLower.contains('crios') &&
      !uaLower.contains('fxios') &&
      !uaLower.contains('edg') &&
      !uaLower.contains('chrome') &&
      !uaLower.contains('chromium');

  DiagnosticsLog.I.updatePhotoAttempt(
    stage: 'webcam_init',
    ua: ua,
    isIOS: isIOS,
    isSafari: isSafari,
    secureContext: WebCapabilities.isSecureContext,
    inAppBrowser: WebCapabilities.isInAppBrowser,
    visibility: html.document.visibilityState,
    hasFocus: html.document.activeElement != null,
    reset: true,
    clearError: true,
    clearStack: true,
  );

  if (!WebCapabilities.isSecureContext) {
    log('photo:webcam blocked insecure', ok: false);
    DiagnosticsLog.I.updatePhotoAttempt(
      stage: 'blocked',
      error: 'insecure',
    );
    return WebCameraCaptureResult.blocked(
      'Necesitas HTTPS para usar la camara.',
    );
  }

  if (WebCapabilities.isInAppBrowser) {
    log('photo:webcam blocked in-app', ok: false);
    DiagnosticsLog.I.updatePhotoAttempt(
      stage: 'blocked',
      error: 'in_app',
    );
    return WebCameraCaptureResult.blocked(
      'Navegador embebido: abri en Safari o Chrome.',
    );
  }

  if (!WebCapabilities.cameraAvailable) {
    log('photo:webcam blocked no-mediaDevices', ok: false);
    DiagnosticsLog.I.updatePhotoAttempt(
      stage: 'blocked',
      error: 'no_media_devices',
    );
    return WebCameraCaptureResult.blocked(
      'La camara no esta disponible en este navegador.',
    );
  }

  try {
    final result = await showGeneralDialog<WebCameraCaptureResult>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Camara',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, anim, sec) {
        return WebCameraOverlay(jpegQuality: jpegQuality);
      },
      transitionBuilder: (ctx, anim, sec, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
    );

    if (result == null) {
      log('photo:webcam cancelled dialog', ok: false);
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'cancelled',
        error: 'cancelled',
      );
      return WebCameraCaptureResult.cancelled();
    }

    if (result.status == WebCameraCaptureStatus.success) {
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'success',
        bytes: result.bytes?.length ?? 0,
        fileName: result.name,
        reportedMime: result.mime,
        sniffedMime: result.mime,
      );
    } else if (result.status == WebCameraCaptureStatus.blocked) {
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'blocked',
        error: result.error ?? 'blocked',
      );
    } else if (result.status == WebCameraCaptureStatus.error) {
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'error',
        error: result.error ?? 'error',
      );
    }

    return result;
  } catch (e) {
    log('photo:webcam dialog_error ', ok: false);
    DiagnosticsLog.I.updatePhotoAttempt(
      stage: 'error',
      error: e.toString(),
    );
    return WebCameraCaptureResult.error('No se pudo abrir la camara: ');
  }
}
