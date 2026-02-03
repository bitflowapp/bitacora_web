import 'force_update_service.dart';

class ForceUpdateServiceImpl implements ForceUpdateService {
  @override
  Future<ForceUpdateResult> forceUpdate() async {
    return const ForceUpdateResult(
      supported: false,
      message: 'Actualización forzada solo disponible en Web.\n'
          'Si ves una versión vieja en iOS Safari: Ajustes ? Safari ? Avanzado ? Datos de sitios web ? borrar el dominio.',
    );
  }
}
