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

  if (!WebCapabilities.isSecureContext) {
    log('photo:webcam blocked insecure', ok: false);
    return WebCameraCaptureResult.blocked(
      'Necesitas HTTPS para usar la camara.',
    );
  }

  if (WebCapabilities.isInAppBrowser) {
    log('photo:webcam blocked in-app', ok: false);
    return WebCameraCaptureResult.blocked(
      'Navegador embebido: abri en Safari o Chrome.',
    );
  }

  if (!WebCapabilities.cameraAvailable) {
    log('photo:webcam blocked no-mediaDevices', ok: false);
    return WebCameraCaptureResult.blocked(
      'La camara no esta disponible en este navegador.',
    );
  }

  try {
    final result = await showGeneralDialog<WebCameraCaptureResult>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Camara',
      barrierColor: Colors.black.withOpacity(0.6),
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
      return WebCameraCaptureResult.cancelled();
    }

    return result;
  } catch (e) {
    log('photo:webcam dialog_error ', ok: false);
    return WebCameraCaptureResult.error('No se pudo abrir la camara: ');
  }
}
