import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'flowbot_local_model_manager.dart';

class _FlowBotLocalModelManagerIo implements FlowBotLocalModelManager {
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
      return await file.length() > 0;
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
        error: 'URL de modelo vacia.',
      );
    }

    HttpClient? client;
    IOSink? sink;
    File? target;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(
        p.join(appDir.path, 'bitflow', 'flowbot_models'),
      );
      await modelsDir.create(recursive: true);
      target = File(
        p.join(modelsDir.path, FlowBotLocalModelManager.defaultModelFileName),
      );

      client = HttpClient();
      final req = await client.getUrl(Uri.parse(cleanUrl));
      final res = await req.close();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return FlowBotModelDownloadResult(
          ok: false,
          error: 'HTTP ${res.statusCode} al descargar modelo.',
        );
      }

      final total = res.contentLength;
      var received = 0;
      sink = target.openWrite(mode: FileMode.writeOnly);
      onProgress?.call(0);
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      final bytes = await target.length();
      if (bytes <= 0) {
        try {
          await target.delete();
        } catch (_) {}
        return const FlowBotModelDownloadResult(
          ok: false,
          error: 'El archivo de modelo quedo vacio.',
        );
      }

      onProgress?.call(1);
      return FlowBotModelDownloadResult(
        ok: true,
        modelPath: target.path,
        bytes: bytes,
      );
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      if (target != null) {
        try {
          if (await target.exists()) {
            await target.delete();
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
