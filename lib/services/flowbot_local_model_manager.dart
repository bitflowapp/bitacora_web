import 'flowbot_local_model_manager_stub.dart'
    if (dart.library.io) 'flowbot_local_model_manager_io.dart';

class FlowBotModelDownloadResult {
  const FlowBotModelDownloadResult({
    required this.ok,
    this.modelPath,
    this.error,
    this.bytes = 0,
  });

  final bool ok;
  final String? modelPath;
  final String? error;
  final int bytes;
}

abstract class FlowBotLocalModelManager {
  static const String defaultModelFileName = 'flowbot-model.gguf';
  static const String defaultModelDownloadUrl =
      'https://github.com/marcoluna-nqn/bitacora_web/releases/latest/download/flowbot-model.gguf';

  Future<FlowBotModelDownloadResult> downloadDefaultModel({
    void Function(double progress)? onProgress,
  });

  Future<bool> modelExists(String modelPath);
}

FlowBotLocalModelManager createFlowBotLocalModelManager() =>
    createFlowBotLocalModelManagerImpl();
