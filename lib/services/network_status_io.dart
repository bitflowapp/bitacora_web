import 'dart:io';

class NetworkStatusService {
  const NetworkStatusService();

  Future<bool> isOnline({Duration timeout = const Duration(seconds: 2)}) async {
    if (_isRunningInFlutterTest()) return true;

    final dnsProbe = _probeSocket('1.1.1.1', 53, timeout);
    final httpProbe = _probeSocket('8.8.8.8', 53, timeout);
    if (await dnsProbe || await httpProbe) return true;

    try {
      final lookup = await InternetAddress.lookup('example.com')
          .timeout(timeout, onTimeout: () => const <InternetAddress>[]);
      return lookup.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _isRunningInFlutterTest() {
    if (bool.fromEnvironment('FLUTTER_TEST')) return true;
    return Platform.environment.containsKey('FLUTTER_TEST');
  }

  Future<bool> _probeSocket(String host, int port, Duration timeout) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }
}
