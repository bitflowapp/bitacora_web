import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class SpreadsheetAuditEntry {
  const SpreadsheetAuditEntry({
    required this.at,
    required this.templateId,
    required this.clientId,
    required this.action,
    required this.detail,
  });

  final DateTime at;
  final String templateId;
  final String clientId;
  final String action;
  final String detail;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'at': at.toIso8601String(),
        'templateId': templateId,
        'clientId': clientId,
        'action': action,
        'detail': detail,
      };

  static SpreadsheetAuditEntry fromJson(Map<String, dynamic> json) {
    return SpreadsheetAuditEntry(
      at: DateTime.tryParse((json['at'] ?? '').toString()) ?? DateTime.now(),
      templateId: (json['templateId'] ?? '').toString(),
      clientId: (json['clientId'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
    );
  }
}

class SpreadsheetAuditLogStore {
  const SpreadsheetAuditLogStore();

  static const String _key = 'spreadsheet_agent.audit.v1';
  static const int _maxEntries = 120;

  Future<void> add(SpreadsheetAuditEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? const <String>[];
    final updated = <String>[jsonEncode(entry.toJson()), ...current];
    if (updated.length > _maxEntries) {
      updated.removeRange(_maxEntries, updated.length);
    }
    await prefs.setStringList(_key, updated);
  }

  Future<List<SpreadsheetAuditEntry>> recent({int limit = 20}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];

    final entries = <SpreadsheetAuditEntry>[];
    for (final value in raw.take(limit)) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          entries.add(SpreadsheetAuditEntry.fromJson(decoded));
        }
      } catch (_) {}
    }
    return entries;
  }
}
