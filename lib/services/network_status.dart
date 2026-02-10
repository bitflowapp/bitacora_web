export 'network_status_stub.dart'
    if (dart.library.io) 'network_status_io.dart'
    if (dart.library.html) 'network_status_web.dart';
