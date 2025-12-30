// Facade STT: elige la impl según la plataforma.
export 'speech_service_stub.dart'
if (dart.library.html) 'speech_service_web_impl.dart'
if (dart.library.io) 'speech_service_io_impl.dart';
