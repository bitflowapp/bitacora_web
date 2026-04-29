enum AppErrorFlow {
  load,
  save,
  exportData,
  importData,
  attachmentPermission,
}

enum AppErrorKind {
  permissionDenied,
  insecureContext,
  timeout,
  invalidData,
  storage,
  unavailable,
  cancelled,
  unknown,
}

class AppError {
  const AppError({
    required this.flow,
    required this.kind,
    required this.userMessage,
    required this.technicalMessage,
    this.code,
  });

  final AppErrorFlow flow;
  final AppErrorKind kind;
  final String userMessage;
  final String technicalMessage;
  final String? code;

  String toLogLine({String? operation}) {
    final op = (operation ?? '').trim();
    final opPart = op.isEmpty ? '' : ' op=$op';
    final codePart = code == null ? '' : ' code=$code';
    return 'flow=${flow.name} kind=${kind.name}$codePart$opPart msg="$technicalMessage"';
  }
}

class AppErrorMapper {
  const AppErrorMapper._();

  static AppError from(
    Object error, {
    required AppErrorFlow flow,
    String? fallbackMessage,
    String? code,
  }) {
    if (error is AppError) return error;
    return fromMessage(
      error.toString(),
      flow: flow,
      fallbackMessage: fallbackMessage,
      code: code,
    );
  }

  static AppError fromMessage(
    String? message, {
    required AppErrorFlow flow,
    String? fallbackMessage,
    String? code,
  }) {
    final raw = _clean(message);
    final lower = raw.toLowerCase();
    final kind = _kindFrom(lower);
    return AppError(
      flow: flow,
      kind: kind,
      userMessage: _userMessage(flow, kind, fallbackMessage: fallbackMessage),
      technicalMessage: raw.isEmpty ? 'unknown_error' : raw,
      code: code,
    );
  }

  static AppErrorKind _kindFrom(String lower) {
    if (lower.isEmpty) return AppErrorKind.unknown;
    if (_containsAny(lower, const [
      'cancelled',
      'canceled',
      'cancelado',
      'cancelada',
      'picker_closed',
      'sheet_closed',
    ])) {
      return AppErrorKind.cancelled;
    }
    if (_containsAny(lower, const [
      'insecure',
      'secure context',
      'https',
      'ssl',
    ])) {
      return AppErrorKind.insecureContext;
    }
    if (_containsAny(lower, const [
      'permission',
      'denied',
      'notallowed',
      'not allowed',
      'forbidden',
      'bloqueado',
      'blocked',
    ])) {
      return AppErrorKind.permissionDenied;
    }
    if (_containsAny(lower, const [
      'timeout',
      'timed out',
      'time out',
    ])) {
      return AppErrorKind.timeout;
    }
    if (_containsAny(lower, const [
      'invalid',
      'decode',
      'json',
      'format',
      'malformed',
      'corrupt',
      'backup.json',
      'backup invalido',
      'no se encontro backup.json',
      'empty_bytes',
      'bytes vacios',
    ])) {
      return AppErrorKind.invalidData;
    }
    if (_containsAny(lower, const [
      'storage',
      'indexeddb',
      'localstorage',
      'quota',
      'disk',
      'write',
      'read',
      'prefs',
      'filesystem',
    ])) {
      return AppErrorKind.storage;
    }
    if (_containsAny(lower, const [
      'network',
      'socket',
      'connection',
      'host lookup',
      'cors',
      'http ',
      'http:',
      'http/',
      'media devices',
      'not available',
      'no disponible',
      'unavailable',
    ])) {
      return AppErrorKind.unavailable;
    }
    return AppErrorKind.unknown;
  }

  static String _userMessage(
    AppErrorFlow flow,
    AppErrorKind kind, {
    String? fallbackMessage,
  }) {
    final fallback = (fallbackMessage ?? '').trim();
    if (fallback.isNotEmpty) return fallback;

    if (flow == AppErrorFlow.attachmentPermission) {
      switch (kind) {
        case AppErrorKind.permissionDenied:
          return 'No se pudo acceder a camara, galeria o microfono. Revisa permisos.';
        case AppErrorKind.insecureContext:
          return 'Necesitas HTTPS para usar camara o microfono.';
        case AppErrorKind.timeout:
          return 'La operacion demoro demasiado. Intenta de nuevo.';
        case AppErrorKind.invalidData:
          return 'No se pudo leer el archivo adjunto seleccionado.';
        case AppErrorKind.storage:
          return 'No se pudo guardar el adjunto en el almacenamiento local.';
        case AppErrorKind.unavailable:
          return 'Esta funcion no esta disponible en este navegador.';
        case AppErrorKind.cancelled:
          return 'Operacion cancelada.';
        case AppErrorKind.unknown:
          return 'No se pudo completar el adjunto. Causa: unknown.';
      }
    }

    if (flow == AppErrorFlow.load) {
      switch (kind) {
        case AppErrorKind.invalidData:
          return 'No pudimos abrir la planilla porque los datos estan danados.';
        case AppErrorKind.storage:
          return 'No pudimos abrir la planilla desde el almacenamiento local.';
        case AppErrorKind.timeout:
          return 'No pudimos abrir la planilla a tiempo. Reintenta.';
        case AppErrorKind.permissionDenied:
        case AppErrorKind.insecureContext:
        case AppErrorKind.unavailable:
        case AppErrorKind.cancelled:
        case AppErrorKind.unknown:
          return 'No pudimos abrir la planilla. Reintenta.';
      }
    }

    if (flow == AppErrorFlow.save) {
      switch (kind) {
        case AppErrorKind.permissionDenied:
        case AppErrorKind.insecureContext:
          return 'No se pudo guardar. Revisa permisos del dispositivo o navegador.';
        case AppErrorKind.storage:
          return 'No se pudo guardar por un problema de almacenamiento local.';
        case AppErrorKind.timeout:
          return 'El guardado demoro demasiado. Intenta de nuevo.';
        case AppErrorKind.invalidData:
        case AppErrorKind.unavailable:
        case AppErrorKind.cancelled:
        case AppErrorKind.unknown:
          return 'No se pudo guardar la planilla. Intenta de nuevo.';
      }
    }

    if (flow == AppErrorFlow.exportData) {
      switch (kind) {
        case AppErrorKind.permissionDenied:
        case AppErrorKind.insecureContext:
          return 'No se pudo exportar. Revisa permisos de archivos o descargas.';
        case AppErrorKind.invalidData:
          return 'No se pudo exportar porque los datos de la planilla no son validos.';
        case AppErrorKind.storage:
          return 'No se pudo exportar por un problema de almacenamiento local.';
        case AppErrorKind.timeout:
          return 'La exportación demoró demasiado. Intenta de nuevo.';
        case AppErrorKind.unavailable:
          return 'No se pudo exportar en este entorno.';
        case AppErrorKind.cancelled:
          return 'Exportacion cancelada.';
        case AppErrorKind.unknown:
          return 'No se pudo exportar el archivo. Intenta de nuevo.';
      }
    }

    switch (kind) {
      case AppErrorKind.invalidData:
        return 'No se pudo importar: el backup parece invalido o danado.';
      case AppErrorKind.permissionDenied:
      case AppErrorKind.insecureContext:
        return 'No se pudo importar. Revisa permisos del dispositivo o navegador.';
      case AppErrorKind.storage:
        return 'No se pudo importar por un problema de almacenamiento local.';
      case AppErrorKind.timeout:
        return 'La importacion demoro demasiado. Intenta de nuevo.';
      case AppErrorKind.unavailable:
        return 'No se pudo importar en este entorno.';
      case AppErrorKind.cancelled:
        return 'Importacion cancelada.';
      case AppErrorKind.unknown:
        return 'No se pudo importar el backup. Verifica el archivo e intenta de nuevo.';
    }
  }

  static String _clean(String? raw) {
    var text = (raw ?? '').trim();
    if (text.startsWith('Exception:')) {
      text = text.substring('Exception:'.length).trim();
    }
    if (text.startsWith('Bad state:')) {
      text = text.substring('Bad state:'.length).trim();
    }
    return text;
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}
