import 'bitflow_product_models.dart';

abstract class BitFlowStorageBackend {
  String get label;
  bool get supportsCloudSync;
  bool get supportsSharing;

  Future<void> init();
  Future<List<BitFlowSheetRecord>> listSheets();
  Future<BitFlowSheetRecord?> loadSheet(String sheetId);
  Future<void> saveSheet(BitFlowSheetRecord record);
  Future<void> deleteSheet(String sheetId);

  Future<BitFlowShareLink> createShareLink({
    required BitFlowSheetRecord record,
    required BitFlowSharePermission permission,
    required String baseUrl,
  });

  Future<BitFlowShareLink?> loadShareLink(String shareId);
  Future<List<BitFlowShareLink>> listShareLinksForSheet(String sheetId);
  Future<void> refreshShareSnapshots(BitFlowSheetRecord record);
}
