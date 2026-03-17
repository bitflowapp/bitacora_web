import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'flowbot_local_model_manager.dart';

class _FlowBotLocalModelManagerIo implements FlowBotLocalModelManager {
  static const Duration _connectTimeout = Duration(seconds: 20);
  static const Duration _readChunkTimeout = Duration(seconds: 30);
  static const Duration _totalDownloadTimeout = Duration(minutes: 20);

  // Evita aceptar archivos vacíos o claramente rotos.
  static const int _minModelBytes = 1024;

  @override
  Future<FlowBotModelDownloadResult> downloadDefaultModel({
    void Function(double progress)? onProgress,
  }) {
    return _downloadFromUrl(
      FlowBotLocalModelManager.defaultModelDownloadUrl,
      onProgress: onProgress,
    );
  }

  @override
  Future<bool> modelExists(String modelPath) async {
    final path = modelPath.trim();
    if (path.isEmpty) return false;

    try {
      final file = File(path);
      if (!await file.exists()) return false;
      return await file.length() >= _minModelBytes;
    } catch (_) {
      return false;
    }
  }

  Future<FlowBotModelDownloadResult> _downloadFromUrl(
      String url, {
        void Function(double progress)? onProgress,
      }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      return const FlowBotModelDownloadResult(
        ok: false,
        error: 'URL de modelo vacía.',
      );
    }

    final uri = Uri.tryParse(cleanUrl);
    final isValidUri = uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.trim().isNotEmpty;

    if (!isValidUri) {
      return const FlowBotModelDownloadResult(
        ok: false,
        error: 'URL de modelo inválida.',
      );
    }

    HttpClient? client;
    IOSink? sink;
    File? tempFile;
    File? targetFile;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(
        p.join(appDir.path, 'bitflow', 'flowbot_models'),
      );
      await modelsDir.create(recursive: true);

      targetFile = File(
        p.join(
          modelsDir.path,
          FlowBotLocalModelManager.defaultModelFileName,
        ),
      );

      tempFile = File('${targetFile.path}.part');

      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      client = HttpClient()..connectionTimeout = _connectTimeout;

      onProgress?.call(0);

      final req = await client.getUrl(uri).timeout(_connectTimeout);
      final res = await req.close().timeout(_connectTimeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return FlowBotModelDownloadResult(
          ok: false,
          error: 'HTTP ${res.statusCode} al descargar modelo.',
        );
      }

      final total = res.contentLength;
      var received = 0;
      final startedAt = DateTime.now();

      sink = tempFile.openWrite(mode: FileMode.writeOnly);

      await for (final chunk in res.timeout(_readChunkTimeout)) {
        final elapsed = DateTime.now().difference(startedAt);
        if (elapsed > _totalDownloadTimeout) {
          throw TimeoutException(
            'Descarga excedió el tiempo máximo permitido.',
            _totalDownloadTimeout,
          );
        }

        sink.add(chunk);
        received += chunk.length;

        if (total > 0) {
          final progress = (received / total).clamp(0.0, 1.0);
          onProgress?.call(progress);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final bytes = await tempFile.length();
      if (bytes < _minModelBytes) {
        try {
          await tempFile.delete();
        } catch (_) {}

        return const FlowBotModelDownloadResult(
          ok: false,
          error: 'El archivo descargado es inválido o quedó incompleto.',
        );
      }

      try {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
      } catch (_) {}

      await tempFile.rename(targetFile.path);

      onProgress?.call(1);

      return FlowBotModelDownloadResult(
        ok: true,
        modelPath: targetFile.path,
        bytes: bytes,
      );
    } on TimeoutException catch (_) {
      try {
        await sink?.flush();
      } catch (_) {}
      try {
        await sink?.close();
      } catch (_) {}

      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }

      return const FlowBotModelDownloadResult(
        ok: false,
        error: 'Timeout al descargar el modelo.',
      );
    } catch (e) {
      try {
        await sink?.flush();
      } catch (_) {}
      try {
        await sink?.close();
      } catch (_) {}

      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }

      return FlowBotModelDownloadResult(
        ok: false,
        error: 'Error descargando modelo: $e',
      );
    } finally {
      client?.close(force: true);
    }
  }
}

FlowBotLocalModelManager createFlowBotLocalModelManagerImpl() =>
    _FlowBotLocalModelManagerIo();