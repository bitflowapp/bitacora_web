import 'package:flutter/widgets.dart';

import 'web_camera_capture_types.dart';

Future<WebCameraCaptureResult> captureFromWebCamera({
  required BuildContext context,
  double jpegQuality = 0.9,
}) async {
  return WebCameraCaptureResult.blocked('Cámara web no disponible.');
}
