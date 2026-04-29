import 'force_update_service.dart';

class ForceUpdateServiceImpl implements ForceUpdateService {
  @override
  Future<ForceUpdateResult> forceUpdate({String? cacheBustValue}) async {
    return const ForceUpdateResult(
      supported: false,
      message: 'Actualizacion forzada solo disponible en Web.\n'
          'Si ves una version vieja en iOS Safari: Ajustes > Safari > Avanzado > Datos de sitios web > borrar el dominio.',
    );
  }

  @override
  Future<bool> hasWebCacheArtifacts() async => false;

  @override
  Future<void> reloadWithCacheBust(String cacheBustValue) async {}
}
