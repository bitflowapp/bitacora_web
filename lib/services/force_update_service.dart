import 'force_update_service_stub.dart'
    if (dart.library.html) 'force_update_service_web.dart';

class ForceUpdateResult {
  const ForceUpdateResult({
    required this.supported,
    required this.message,
    this.reloaded = false,
  });

  final bool supported;
  final bool reloaded;
  final String message;
}

abstract class ForceUpdateService {
  static ForceUpdateService get I => ForceUpdateServiceImpl();

  Future<ForceUpdateResult> forceUpdate();
}
