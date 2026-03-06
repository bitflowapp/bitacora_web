import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bitflow_product_models.dart';

class BitFlowWorkspaceService {
  BitFlowWorkspaceService._();

  static final BitFlowWorkspaceService I = BitFlowWorkspaceService._();

  static const String _prefsWorkspaces = 'bitflow.product.workspaces.v1';
  static const String _prefsCurrentWorkspace =
      'bitflow.product.current_workspace.v1';
  static const String _prefsSheetAssignments =
      'bitflow.product.sheet_workspace_map.v1';

  final ValueNotifier<List<BitFlowWorkspace>> workspaces =
      ValueNotifier<List<BitFlowWorkspace>>(<BitFlowWorkspace>[]);
  final ValueNotifier<String?> currentWorkspaceId = ValueNotifier<String?>(null);

  SharedPreferences? _prefs;
  final Map<String, String> _sheetAssignments = <String, String>{};
  bool _initialized = false;

  bool get isInitialized => _initialized;
  Map<String, String> get sheetAssignments =>
      Map<String, String>.unmodifiable(_sheetAssignments);

  BitFlowWorkspace? get currentWorkspace {
    final wanted = currentWorkspaceId.value;
    final list = workspaces.value;
    if (wanted != null) {
      for (final workspace in list) {
        if (workspace.id == wanted) return workspace;
      }
    }
    return list.isEmpty ? null : list.first;
  }

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _loadLocal();
    _initialized = true;
  }

  Future<void> _loadLocal() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final rawWorkspaces = prefs.getString(_prefsWorkspaces) ?? '[]';
    final rawAssignments = prefs.getString(_prefsSheetAssignments) ?? '{}';
    final wantedCurrent = (prefs.getString(_prefsCurrentWorkspace) ?? '').trim();

    final decodedWorkspaces = <BitFlowWorkspace>[];
    try {
      final decoded = jsonDecode(rawWorkspaces);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            decodedWorkspaces.add(
              BitFlowWorkspace.fromJson(item.cast<String, dynamic>()),
            );
          }
        }
      }
    } catch (_) {}

    if (decodedWorkspaces.isEmpty) {
      final now = DateTime.now().toUtc();
      decodedWorkspaces.addAll(<BitFlowWorkspace>[
        BitFlowWorkspace(
          id: 'personal',
          name: 'Personal',
          createdAt: now,
          updatedAt: now,
          isDefault: true,
        ),
        BitFlowWorkspace(
          id: 'company',
          name: 'Company',
          createdAt: now,
          updatedAt: now,
        ),
        BitFlowWorkspace(
          id: 'projects',
          name: 'Projects',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    }

    _sheetAssignments.clear();
    try {
      final decoded = jsonDecode(rawAssignments);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          final sheetId = key.toString().trim();
          final workspaceId = value.toString().trim();
          if (sheetId.isEmpty || workspaceId.isEmpty) return;
          _sheetAssignments[sheetId] = workspaceId;
        });
      }
    } catch (_) {}

    decodedWorkspaces.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    workspaces.value = List<BitFlowWorkspace>.unmodifiable(decodedWorkspaces);
    final fallbackCurrent = decodedWorkspaces.first.id;
    currentWorkspaceId.value = wantedCurrent.isNotEmpty
        ? wantedCurrent
        : fallbackCurrent;

    await _persistLocal();
  }

  Future<void> _persistLocal() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _prefsWorkspaces,
      jsonEncode(
        workspaces.value.map((workspace) => workspace.toJson()).toList(),
      ),
    );
    await prefs.setString(
      _prefsSheetAssignments,
      jsonEncode(_sheetAssignments),
    );
    final current = currentWorkspaceId.value ?? currentWorkspace?.id ?? 'personal';
    await prefs.setString(_prefsCurrentWorkspace, current);
  }

  Future<void> reconcileSheets(Iterable<String> knownSheetIds) async {
    await init();
    final validWorkspaceIds = workspaces.value.map((w) => w.id).toSet();
    final fallback = currentWorkspace?.id ?? 'personal';
    var changed = false;

    for (final rawId in knownSheetIds) {
      final sheetId = rawId.trim();
      if (sheetId.isEmpty) continue;
      final assigned = _sheetAssignments[sheetId];
      if (assigned == null || !validWorkspaceIds.contains(assigned)) {
        _sheetAssignments[sheetId] = fallback;
        changed = true;
      }
    }

    final known = knownSheetIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    final stale = _sheetAssignments.keys.where((id) => !known.contains(id)).toList();
    if (stale.isNotEmpty) {
      for (final id in stale) {
        _sheetAssignments.remove(id);
      }
      changed = true;
    }

    if (changed) {
      await _persistLocal();
    }
  }

  String workspaceForSheet(String sheetId) {
    final trimmed = sheetId.trim();
    if (trimmed.isEmpty) return currentWorkspace?.id ?? 'personal';
    return _sheetAssignments[trimmed] ?? currentWorkspace?.id ?? 'personal';
  }

  bool isInCurrentWorkspace(String sheetId) {
    return workspaceForSheet(sheetId) == (currentWorkspace?.id ?? 'personal');
  }

  Future<void> switchWorkspace(String workspaceId) async {
    await init();
    if (!workspaces.value.any((workspace) => workspace.id == workspaceId)) {
      return;
    }
    currentWorkspaceId.value = workspaceId;
    await _persistLocal();
  }

  Future<BitFlowWorkspace> createWorkspace(String rawName) async {
    await init();
    final name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError('workspace_name_empty');
    }
    final now = DateTime.now().toUtc();
    final workspace = BitFlowWorkspace(
      id: _workspaceIdFromName(name, now),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    workspaces.value = List<BitFlowWorkspace>.unmodifiable(<BitFlowWorkspace>[
      ...workspaces.value,
      workspace,
    ]);
    await switchWorkspace(workspace.id);
    return workspace;
  }

  Future<void> renameWorkspace(String workspaceId, String rawName) async {
    await init();
    final name = rawName.trim();
    if (name.isEmpty) return;
    workspaces.value = List<BitFlowWorkspace>.unmodifiable(
      workspaces.value.map((workspace) {
        if (workspace.id != workspaceId) return workspace;
        return workspace.copyWith(
          name: name,
          updatedAt: DateTime.now().toUtc(),
        );
      }).toList(growable: false),
    );
    await _persistLocal();
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    await init();
    final list = workspaces.value;
    if (list.length <= 1) return;
    final target = list.where((workspace) => workspace.id != workspaceId).toList();
    if (target.isEmpty) return;
    final fallback = target.firstWhere(
      (workspace) => workspace.isDefault,
      orElse: () => target.first,
    );
    for (final entry in _sheetAssignments.entries.toList()) {
      if (entry.value == workspaceId) {
        _sheetAssignments[entry.key] = fallback.id;
      }
    }
    workspaces.value = List<BitFlowWorkspace>.unmodifiable(target);
    if (currentWorkspaceId.value == workspaceId) {
      currentWorkspaceId.value = fallback.id;
    }
    await _persistLocal();
  }

  Future<void> assignSheetToCurrentWorkspace(String sheetId) async {
    await init();
    final trimmed = sheetId.trim();
    if (trimmed.isEmpty) return;
    _sheetAssignments[trimmed] = currentWorkspace?.id ?? 'personal';
    await _persistLocal();
  }

  Future<void> moveSheetToWorkspace(String sheetId, String workspaceId) async {
    await init();
    final trimmed = sheetId.trim();
    if (trimmed.isEmpty) return;
    if (!workspaces.value.any((workspace) => workspace.id == workspaceId)) {
      return;
    }
    _sheetAssignments[trimmed] = workspaceId;
    await _persistLocal();
  }

  Future<void> duplicateAssignment(String sourceSheetId, String targetSheetId) async {
    await init();
    _sheetAssignments[targetSheetId] = workspaceForSheet(sourceSheetId);
    await _persistLocal();
  }

  Future<void> removeSheet(String sheetId) async {
    await init();
    _sheetAssignments.remove(sheetId);
    await _persistLocal();
  }

  Future<void> importFromCloud({required String userId}) async {
    await init();
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('workspaces')
        .orderBy('updatedAt', descending: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final merged = <String, BitFlowWorkspace>{
      for (final workspace in workspaces.value) workspace.id: workspace,
    };
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final workspace = BitFlowWorkspace(
        id: doc.id,
        name: (data['name'] ?? '').toString().trim().isEmpty
            ? doc.id
            : (data['name'] ?? '').toString(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate().toUtc() ??
            DateTime.now().toUtc(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate().toUtc() ??
            DateTime.now().toUtc(),
        isDefault: data['isDefault'] == true,
      );
      merged[workspace.id] = workspace;
    }
    workspaces.value = List<BitFlowWorkspace>.unmodifiable(
      merged.values.toList(growable: false)
        ..sort((a, b) {
          if (a.isDefault != b.isDefault) {
            return a.isDefault ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }),
    );
    await _persistLocal();
  }

  Future<void> exportToCloud({required String userId}) async {
    await init();
    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('workspaces');

    for (final workspace in workspaces.value) {
      batch.set(
        collection.doc(workspace.id),
        <String, dynamic>{
          'name': workspace.name,
          'isDefault': workspace.isDefault,
          'createdAt': Timestamp.fromDate(workspace.createdAt.toUtc()),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  static String _workspaceIdFromName(String name, DateTime now) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final safe = slug.isEmpty ? 'workspace' : slug;
    return '$safe-${now.microsecondsSinceEpoch.toRadixString(36)}';
  }
}
