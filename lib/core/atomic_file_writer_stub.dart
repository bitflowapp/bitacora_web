class AtomicFileWriter {
  const AtomicFileWriter();

  bool get isSupported => false;

  Future<void> writeStringAtomic(
    String path,
    String data, {
    bool simulateSwapFailure = false,
  }) async {
    throw UnsupportedError('Atomic file writing is not supported.');
  }
}
