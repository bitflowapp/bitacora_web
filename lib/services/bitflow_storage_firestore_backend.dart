import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'bitflow_product_models.dart';
import 'bitflow_storage_backend.dart';

class FirestoreBitFlowStorageBackend implements BitFlowStorageBackend {
  FirestoreBitFlowStorageBackend();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  String get label => 'firestore';

  @override
  bool get supportsCloudSync => true;

  @override
  bool get supportsSharing => true;

  CollectionReference<Map<String, dynamic>> _sheetCollectionFor(String uid) {
    return _firestore.collection('users').doc(uid).collection('sheets');
  }

  CollectionReference<Map<String, dynamic>> get _shareCollection =>
      _firestore.collection('bitflow_shares');

  @override
  Future<void> init() async {}

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('auth_required');
    }
    return user.uid;
  }

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('auth_required');
    }
    return user;
  }

  @override
  Future<List<BitFlowSheetRecord>> listSheets() async {
    final snapshot = await _sheetCollectionFor(_uid)
        .orderBy('updatedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => _recordFromDoc(doc.id, doc.data()))
        .toList(growable: false);
  }

  @override
  Future<BitFlowSheetRecord?> loadSheet(String sheetId) async {
    final doc = await _sheetCollectionFor(_uid).doc(sheetId).get();
    if (!doc.exists || doc.data() == null) return null;
    return _recordFromDoc(doc.id, doc.data()!);
  }

  BitFlowSheetRecord _recordFromDoc(String sheetId, Map<String, dynamic> data) {
    return BitFlowSheetRecord(
      sheetId: sheetId,
      title: (data['title'] ?? '').toString(),
      rawJson: (data['rawJson'] ?? '{}').toString(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate().toUtc() ??
          DateTime.now().toUtc(),
      rows: (data['rows'] as num?)?.toInt() ?? 0,
      workspaceId: (data['workspaceId'] ?? 'personal').toString(),
      ownerUserId: (data['ownerUserId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['ownerUserId'] ?? '').toString(),
      origin: label,
    );
  }

  @override
  Future<void> saveSheet(BitFlowSheetRecord record) async {
    final user = _user;
    await _sheetCollectionFor(user.uid).doc(record.sheetId).set(
      <String, dynamic>{
        'title': record.title,
        'rawJson': record.rawJson,
        'updatedAt': FieldValue.serverTimestamp(),
        'rows': record.rows,
        'workspaceId': record.workspaceId,
        'ownerUserId': user.uid,
        'ownerEmail': user.email,
        'model': jsonDecode(record.rawJson),
      },
      SetOptions(merge: true),
    );
    await refreshShareSnapshots(
      record.copyWith(ownerUserId: user.uid, origin: label),
    );
  }

  @override
  Future<void> deleteSheet(String sheetId) async {
    final uid = _uid;
    await _sheetCollectionFor(uid).doc(sheetId).delete();
    final shares = await _shareCollection
        .where('ownerUserId', isEqualTo: uid)
        .where('sheetId', isEqualTo: sheetId)
        .get();
    if (shares.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in shares.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Future<BitFlowShareLink> createShareLink({
    required BitFlowSheetRecord record,
    required BitFlowSharePermission permission,
    required String baseUrl,
  }) async {
    final user = _user;
    final safeBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final doc = _shareCollection.doc();
    final now = DateTime.now().toUtc();
    final share = BitFlowShareLink(
      id: doc.id,
      sheetId: record.sheetId,
      permission: permission,
      url: '$safeBase/shared/${doc.id}',
      title: record.title,
      snapshotRawJson: record.rawJson,
      workspaceId: record.workspaceId,
      createdAt: now,
      updatedAt: now,
      ownerUserId: user.uid,
      ownerEmail: user.email,
      storageLabel: label,
    );
    await doc.set(<String, dynamic>{
      'sheetId': share.sheetId,
      'permission': share.permission.name,
      'url': share.url,
      'title': share.title,
      'snapshotRawJson': share.snapshotRawJson,
      'workspaceId': share.workspaceId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'ownerUserId': share.ownerUserId,
      'ownerEmail': share.ownerEmail,
      'storageLabel': share.storageLabel,
    });
    return share;
  }

  @override
  Future<BitFlowShareLink?> loadShareLink(String shareId) async {
    final doc = await _shareCollection.doc(shareId).get();
    if (!doc.exists || doc.data() == null) return null;
    return _shareFromDoc(doc.id, doc.data()!);
  }

  @override
  Future<List<BitFlowShareLink>> listShareLinksForSheet(String sheetId) async {
    final uid = _uid;
    final snapshot = await _shareCollection
        .where('ownerUserId', isEqualTo: uid)
        .where('sheetId', isEqualTo: sheetId)
        .get();
    return snapshot.docs
        .map((doc) => _shareFromDoc(doc.id, doc.data()))
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  BitFlowShareLink _shareFromDoc(String shareId, Map<String, dynamic> data) {
    return BitFlowShareLink(
      id: shareId,
      sheetId: (data['sheetId'] ?? '').toString(),
      permission: BitFlowSharePermission.values.firstWhere(
        (value) => value.name == (data['permission'] ?? 'view').toString(),
        orElse: () => BitFlowSharePermission.view,
      ),
      url: (data['url'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      snapshotRawJson: (data['snapshotRawJson'] ?? '{}').toString(),
      workspaceId: (data['workspaceId'] ?? 'personal').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate().toUtc() ??
          DateTime.now().toUtc(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate().toUtc() ??
          DateTime.now().toUtc(),
      ownerUserId: (data['ownerUserId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['ownerUserId'] ?? '').toString(),
      ownerEmail: (data['ownerEmail'] ?? '').toString().trim().isEmpty
          ? null
          : (data['ownerEmail'] ?? '').toString(),
      storageLabel: (data['storageLabel'] ?? label).toString(),
    );
  }

  @override
  Future<void> refreshShareSnapshots(BitFlowSheetRecord record) async {
    final uid = _uid;
    final snapshot = await _shareCollection
        .where('ownerUserId', isEqualTo: uid)
        .where('sheetId', isEqualTo: record.sheetId)
        .get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.set(
        doc.reference,
        <String, dynamic>{
          'title': record.title,
          'snapshotRawJson': record.rawJson,
          'workspaceId': record.workspaceId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}
