import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'bitflow_feature_service.dart';
import 'bitflow_product_models.dart';
import 'bitflow_storage_backend.dart';
import 'bitflow_storage_firestore_backend.dart';
import 'bitflow_storage_local_backend.dart';
import 'bitflow_workspace_service.dart';
import 'sheet_store.dart';

class BitFlowProductService {
  BitFlowProductService._();

  static final BitFlowProductService I = BitFlowProductService._();

  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  final ValueNotifier<bool> syncBusy = ValueNotifier<bool>(false);
  final ValueNotifier<String> syncStatus =
  ValueNotifier<String>('Local storage only');
  final ValueNotifier<DateTime?> lastSyncAt = ValueNotifier<DateTime?>(null);

  final LocalBitFlowStorageBackend _localBackend = LocalBitFlowStorageBackend();
  BitFlowStorageBackend? _cloudBackend;

  bool _initialized = false;
  bool _firebaseAvailable = false;
  bool _paidFeatureEnforcement = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  Future<void>? _syncInFlight;

  bool get isInitialized => _initialized;
  bool get firebaseAvailable => _firebaseAvailable;
  bool get cloudSyncEnabled => _cloudBackend != null;

  String? get currentUserId => _firebaseAvailable
      ? FirebaseAuth.instance.currentUser?.uid
      : null;

  BitFlowWorkspaceService get workspaces => BitFlowWorkspaceService.I;
  BitFlowFeatureService get features => BitFlowFeatureService.I;

  Future<void> ensureInitialized({
    bool firebaseAvailable = false,
    bool enforcePaidFeatures = false,
  }) async {
    if (_initialized) {
      if (firebaseAvailable && !_firebaseAvailable) {
        _firebaseAvailable = true;
        _cloudBackend ??= FirestoreBitFlowStorageBackend();
        await _startFirebaseListeners();
      }
      if (enforcePaidFeatures && !_paidFeatureEnforcement) {
        _paidFeatureEnforcement = true;
        await features.init(enforcePaidFeatures: true);
      }
      return;
    }

    _firebaseAvailable = firebaseAvailable;
    _paidFeatureEnforcement = enforcePaidFeatures;

    await features.init(enforcePaidFeatures: enforcePaidFeatures);
    await _localBackend.init();
    await workspaces.init();
    await workspaces.reconcileSheets(SheetStore.list().map((sheet) => sheet.id));

    if (_firebaseAvailable) {
      _cloudBackend = FirestoreBitFlowStorageBackend();
      await _startFirebaseListeners();
    } else {
      features.updateEntitlement(BitFlowEntitlement.free);
      syncStatus.value = 'Local storage only';
    }

    ready.value = true;
    _initialized = true;
  }

  Future<void> _startFirebaseListeners() async {
    await _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_handleAuthChanged(user));
    });
    await _handleAuthChanged(FirebaseAuth.instance.currentUser);
  }

  Future<void> _handleAuthChanged(User? user) async {
    await _userDocSub?.cancel();

    if (user == null) {
      features.updateEntitlement(BitFlowEntitlement.free);
      syncStatus.value = _firebaseAvailable
          ? 'Sign in to sync sheets to your account'
          : 'Local storage only';
      return;
    }

    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      _applyEntitlement(doc.data(), user: user);
    });

    await workspaces.importFromCloud(userId: user.uid);
    await workspaces.exportToCloud(userId: user.uid);
    await syncNow(reason: 'auth');
  }

  void _applyEntitlement(Map<String, dynamic>? data, {required User user}) {
    final isPremium = data?['isPremium'] == true;
    final trialEndsAt = (data?['trialEndsAt'] as Timestamp?)?.toDate().toUtc();
    final trialActive =
        trialEndsAt != null && DateTime.now().toUtc().isBefore(trialEndsAt);
    final providerName = (data?['billingProvider'] ?? '').toString();
    final provider = BitFlowPaymentProvider.values.where(
          (value) => value.name == providerName,
    );

    if (isPremium || trialActive) {
      features.updateEntitlement(
        BitFlowEntitlement.pro.copyWith(
          signedIn: true,
          source: isPremium ? 'billing' : 'trial',
          trialEndsAt: trialEndsAt,
          provider: provider.isEmpty ? null : provider.first,
        ),
      );
      return;
    }

    features.updateEntitlement(
      BitFlowEntitlement.free.copyWith(
        signedIn: true,
        source: 'free',
      ),
    );
    syncStatus.value = 'Signed in as ${user.email ?? user.uid}';
  }

  List<SheetMeta> filterSheetsForCurrentWorkspace(Iterable<SheetMeta> sheets) {
    final currentWorkspace = workspaces.currentWorkspace;
    if (currentWorkspace == null) {
      return sheets.toList(growable: false);
    }

    return sheets
        .where(
          (sheet) =>
      workspaces.workspaceForSheet(sheet.id) == currentWorkspace.id,
    )
        .toList(growable: false);
  }

  Future<void> syncNow({String reason = 'manual'}) async {
    final current = _syncInFlight;
    if (current != null) {
      return current;
    }

    final future = _performSync(reason: reason);
    _syncInFlight = future;

    try {
      await future;
    } finally {
      if (identical(_syncInFlight, future)) {
        _syncInFlight = null;
      }
    }
  }

  Future<void> _performSync({required String reason}) async {
    final backend = _cloudBackend;
    final userId = currentUserId;

    if (backend == null || userId == null) {
      syncStatus.value = 'Local storage only';
      return;
    }

    syncBusy.value = true;
    syncStatus.value =
    reason == 'auth' ? 'Syncing account...' : 'Syncing now...';

    try {
      await _syncWorkspaceAssignments(userId: userId);

      syncStatus.value = 'Comparing local and cloud sheets...';

      final localSheets = await _localBackend.listSheets();
      final remoteSheets = await backend.listSheets();

      final localById = <String, BitFlowSheetRecord>{
        for (final record in localSheets) record.sheetId: record,
      };
      final remoteById = <String, BitFlowSheetRecord>{
        for (final record in remoteSheets) record.sheetId: record,
      };

      final pushed = await _pushLocalSheetsToCloud(
        backend: backend,
        userId: userId,
        localSheets: localSheets,
        remoteById: remoteById,
      );

      final pulled = await _pullRemoteSheetsToLocal(
        remoteSheets: remoteSheets,
        localById: localById,
      );

      lastSyncAt.value = DateTime.now().toUtc();
      syncStatus.value = _buildSyncCompletedMessage(
        pushed: pushed,
        pulled: pulled,
      );
    } catch (error, stackTrace) {
      debugPrint('BitFlowProductService._performSync error: $error');
      debugPrint('$stackTrace');
      syncStatus.value = 'Sync failed';
    } finally {
      syncBusy.value = false;
    }
  }

  Future<void> _syncWorkspaceAssignments({required String userId}) async {
    syncStatus.value = 'Syncing workspaces...';
    await workspaces.reconcileSheets(SheetStore.list().map((sheet) => sheet.id));
    await workspaces.importFromCloud(userId: userId);
    await workspaces.exportToCloud(userId: userId);
  }

  Future<int> _pushLocalSheetsToCloud({
    required BitFlowStorageBackend backend,
    required String userId,
    required List<BitFlowSheetRecord> localSheets,
    required Map<String, BitFlowSheetRecord> remoteById,
  }) async {
    if (localSheets.isEmpty) return 0;

    syncStatus.value = 'Uploading local changes...';

    var pushed = 0;
    for (final local in localSheets) {
      final remote = remoteById[local.sheetId];
      final shouldPush =
          remote == null || !remote.updatedAt.isAfter(local.updatedAt);

      if (!shouldPush) continue;

      await backend.saveSheet(
        local.copyWith(
          ownerUserId: userId,
          origin: backend.label,
        ),
      );
      pushed++;
    }

    return pushed;
  }

  Future<int> _pullRemoteSheetsToLocal({
    required List<BitFlowSheetRecord> remoteSheets,
    required Map<String, BitFlowSheetRecord> localById,
  }) async {
    if (remoteSheets.isEmpty) return 0;

    syncStatus.value = 'Downloading cloud changes...';

    var pulled = 0;
    for (final remote in remoteSheets) {
      final local = localById[remote.sheetId];
      final shouldPull =
          local == null || remote.updatedAt.isAfter(local.updatedAt);

      if (!shouldPull) continue;

      await _localBackend.saveSheet(
        remote.copyWith(origin: _localBackend.label),
      );
      pulled++;
    }

    return pulled;
  }

  String _buildSyncCompletedMessage({
    required int pushed,
    required int pulled,
  }) {
    if (pushed == 0 && pulled == 0) {
      return 'Already up to date';
    }

    final parts = <String>[];
    if (pushed > 0) {
      parts.add('$pushed uploaded');
    }
    if (pulled > 0) {
      parts.add('$pulled downloaded');
    }

    return 'Synced · ${parts.join(' · ')}';
  }

  Future<void> handleLocalSheetSaved(String sheetId) async {
    await ensureInitialized(
      firebaseAvailable: _firebaseAvailable,
      enforcePaidFeatures: _paidFeatureEnforcement,
    );
    await workspaces.reconcileSheets(SheetStore.list().map((sheet) => sheet.id));

    final record = await _localBackend.loadSheet(sheetId);
    if (record == null) return;

    await _localBackend.refreshShareSnapshots(record);

    final backend = _cloudBackend;
    final userId = currentUserId;
    if (backend == null || userId == null) return;

    await backend.saveSheet(record.copyWith(ownerUserId: userId));
    syncStatus.value = 'Sheet saved to account';
    lastSyncAt.value = DateTime.now().toUtc();
  }

  Future<void> handleLocalSheetDeleted(String sheetId) async {
    await workspaces.removeSheet(sheetId);

    final backend = _cloudBackend;
    final userId = currentUserId;
    if (backend == null || userId == null) return;

    await backend.deleteSheet(sheetId);
    syncStatus.value = 'Sheet removed from account';
    lastSyncAt.value = DateTime.now().toUtc();
  }

  Future<void> handleLocalSheetDuplicated(
      String sourceSheetId,
      String duplicatedSheetId,
      ) async {
    await workspaces.duplicateAssignment(sourceSheetId, duplicatedSheetId);
    await handleLocalSheetSaved(duplicatedSheetId);
  }

  Future<BitFlowShareLink> createShareLinkForSheet({
    required SheetMeta meta,
    required BitFlowSharePermission permission,
    required String baseUrl,
  }) async {
    await ensureInitialized(
      firebaseAvailable: _firebaseAvailable,
      enforcePaidFeatures: _paidFeatureEnforcement,
    );

    if (!features.isEnabled(BitFlowFeature.sharing)) {
      throw StateError(
        features.featureBlockedReason(BitFlowFeature.sharing) ??
            'sharing_locked',
      );
    }

    final localRecord = await _localBackend.loadSheet(meta.id);
    if (localRecord == null) {
      throw StateError('sheet_not_found');
    }

    final backend = _cloudBackend ?? _localBackend;
    final share = await backend.createShareLink(
      record: localRecord,
      permission: permission,
      baseUrl: baseUrl,
    );

    syncStatus.value = 'Share link ready';
    return share;
  }

  Future<List<BitFlowShareLink>> listShareLinksForSheet(String sheetId) async {
    final backend = _cloudBackend ?? _localBackend;
    return backend.listShareLinksForSheet(sheetId);
  }

  Future<BitFlowShareLink?> loadShareLink(String shareId) async {
    if (_cloudBackend != null) {
      final cloudShare = await _cloudBackend!.loadShareLink(shareId);
      if (cloudShare != null) return cloudShare;
    }
    return _localBackend.loadShareLink(shareId);
  }

  Future<String> importSharedSheet(
      BitFlowShareLink share, {
        bool preferOriginalSheetId = false,
      }) async {
    await ensureInitialized(
      firebaseAvailable: _firebaseAvailable,
      enforcePaidFeatures: _paidFeatureEnforcement,
    );

    final decoded = jsonDecode(share.snapshotRawJson);
    if (decoded is! Map) {
      throw const FormatException('shared_payload_invalid');
    }

    final normalized = SheetStore.normalizeModel(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );

    String sheetId;
    final currentUid = currentUserId;
    final canUseOriginalId = preferOriginalSheetId &&
        share.permission == BitFlowSharePermission.edit &&
        currentUid != null &&
        share.ownerUserId == currentUid;

    if (canUseOriginalId) {
      sheetId = share.sheetId;
      SheetStore.saveModel(sheetId, normalized);
    } else {
      sheetId = SheetStore.createFromModel(normalized);
    }

    await workspaces.assignSheetToCurrentWorkspace(sheetId);
    await handleLocalSheetSaved(sheetId);
    return sheetId;
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _userDocSub?.cancel();
  }
}