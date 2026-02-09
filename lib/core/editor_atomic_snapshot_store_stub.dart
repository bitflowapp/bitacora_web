class EditorAtomicSnapshotStore {
  const EditorAtomicSnapshotStore();

  bool get isSupported => false;

  Future<bool> writeSnapshot({
    required String sheetId,
    required String payload,
    bool simulateSwapFailure = false,
  }) async {
    return false;
  }

  Future<String?> readSnapshot(String sheetId) async {
    return null;
  }
}
