class NetworkStatusService {
  const NetworkStatusService();

  Future<bool> isOnline({Duration timeout = const Duration(seconds: 2)}) async {
    return true;
  }
}
