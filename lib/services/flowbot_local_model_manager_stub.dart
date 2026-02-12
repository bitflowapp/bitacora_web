import 'flowbot_local_model_manager.dart';

class _FlowBotLocalModelManagerStub implements FlowBotLocalModelManager {
  @override
  Future<FlowBotModelDownloadResult> downloadDefaultModel({
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0);
    return const FlowBotModelDownloadResult(
      ok: false,
      error: 'Local LLM no disponible en esta plataforma.',
    );
  }

  @override
  Future<bool> modelExists(String modelPath) async => false;
}

FlowBotLocalModelManager createFlowBotLocalModelManagerImpl() =>
    _FlowBotLocalModelManagerStub();
