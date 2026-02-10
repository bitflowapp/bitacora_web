class OfflineQueueStore {
  const OfflineQueueStore();

  bool get isPersistent => false;

  Future<String?> read(String sheetId) async => null;

  Future<void> write({
    required String sheetId,
    required String payload,
  }) async {}

  Future<void> delete(String sheetId) async {}
}
