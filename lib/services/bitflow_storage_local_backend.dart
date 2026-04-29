import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'bitflow_product_models.dart';
import 'bitflow_storage_backend.dart';
import 'bitflow_workspace_service.dart';
import 'sheet_store.dart';

class LocalBitFlowStorageBackend implements BitFlowStorageBackend {
  static const String _prefsShares = 'bitflow.product.local_shares.v1';

  SharedPreferences? _prefs;

  @override
  String get label => 'local';

  @override
  bool get supportsCloudSync => false;

  @override
  bool get supportsSharing => true;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await BitFlowWorkspaceService.I.init();
  }

  @override
  Future<List<BitFlowSheetRecord>> listSheets() async {
    await init();
    await BitFlowWorkspaceService.I.reconcileSheets(
      SheetStore.list().map((sheet) => sheet.id),
    );
    return SheetStore.list().map(_recordFromMeta).toList(growable: false);
  }

  @override
  Future<BitFlowSheetRecord?> loadSheet(String sheetId) async {
    await init();
    final meta = SheetStore.list().cast<SheetMeta?>().firstWhere(
          (sheet) => sheet?.id == sheetId,
          orElse: () => null,
        );
    if (meta == null) return null;
    return _recordFromMeta(meta);
  }

  BitFlowSheetRecord _recordFromMeta(SheetMeta meta) {
    final rawJson = SheetStore.loadRaw(meta.id) ?? '{}';
    return BitFlowSheetRecord(
      sheetId: meta.id,
      title: meta.title,
      rawJson: rawJson,
      updatedAt: meta.updatedAt.toUtc(),
      rows: meta.rows,
      workspaceId: BitFlowWorkspaceService.I.workspaceForSheet(meta.id),
      origin: label,
    );
  }

  @override
  Future<void> saveSheet(BitFlowSheetRecord record) async {
    await init();
    final decoded = jsonDecode(record.rawJson);
    if (decoded is Map<String, dynamic>) {
      SheetStore.saveModel(record.sheetId, decoded);
    } else if (decoded is Map) {
      SheetStore.saveModel(
        record.sheetId,
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    await BitFlowWorkspaceService.I.moveSheetToWorkspace(
      record.sheetId,
      record.workspaceId,
    );
    await refreshShareSnapshots(record);
  }

  @override
  Future<void> deleteSheet(String sheetId) async {
    await init();
    SheetStore.delete(sheetId);
    await BitFlowWorkspaceService.I.removeSheet(sheetId);
    final shares = await _loadSharesMap();
    final stale = shares.entries
        .where((entry) => entry.value.sheetId == sheetId)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in stale) {
      shares.remove(key);
    }
    await _persistSharesMap(shares);
  }

  @override
  Future<BitFlowShareLink> createShareLink({
    required BitFlowSheetRecord record,
    required BitFlowSharePermission permission,
    required String baseUrl,
  }) async {
    await init();
    final now = DateTime.now().toUtc();
    final shareId = 'local_${now.microsecondsSinceEpoch.toRadixString(36)}';
    final safeBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final share = BitFlowShareLink(
      id: shareId,
      sheetId: record.sheetId,
      permission: permission,
      url: '$safeBase/shared/$shareId',
      title: record.title,
      snapshotRawJson: record.rawJson,
      workspaceId: record.workspaceId,
      createdAt: now,
      updatedAt: now,
      storageLabel: label,
    );
    final shares = await _loadSharesMap();
    shares[shareId] = share;
    await _persistSharesMap(shares);
    return share;
  }

  @override
  Future<BitFlowShareLink?> loadShareLink(String shareId) async {
    await init();
    final shares = await _loadSharesMap();
    return shares[shareId];
  }

  @override
  Future<List<BitFlowShareLink>> listShareLinksForSheet(String sheetId) async {
    await init();
    final shares = await _loadSharesMap();
    return shares.values
        .where((share) => share.sheetId == sheetId)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> refreshShareSnapshots(BitFlowSheetRecord record) async {
    await init();
    final shares = await _loadSharesMap();
    var changed = false;
    shares.updateAll((key, share) {
      if (share.sheetId != record.sheetId) return share;
      changed = true;
      return share.copyWith(
        title: record.title,
        snapshotRawJson: record.rawJson,
        workspaceId: record.workspaceId,
        updatedAt: DateTime.now().toUtc(),
      );
    });
    if (changed) {
      await _persistSharesMap(shares);
    }
  }

  Future<Map<String, BitFlowShareLink>> _loadSharesMap() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsShares) ?? '{}';
    final out = <String, BitFlowShareLink>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (value is Map) {
            out[key.toString()] =
                BitFlowShareLink.fromJson(value.cast<String, dynamic>());
          }
        });
      }
    } catch (_) {}
    return out;
  }

  Future<void> _persistSharesMap(Map<String, BitFlowShareLink> shares) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsShares,
      jsonEncode(
        shares.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }
}
