import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class SpreadsheetMappingProfile {
  const SpreadsheetMappingProfile({
    required this.templateId,
    required this.clientId,
    required this.headerToField,
    required this.defaultValues,
    required this.updatedAt,
  });

  final String templateId;
  final String clientId;
  final Map<String, String> headerToField;
  final Map<String, String> defaultValues;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'templateId': templateId,
        'clientId': clientId,
        'headerToField': headerToField,
        'defaultValues': defaultValues,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static SpreadsheetMappingProfile fromJson(Map<String, dynamic> json) {
    return SpreadsheetMappingProfile(
      templateId: (json['templateId'] ?? '').toString(),
      clientId: (json['clientId'] ?? '').toString(),
      headerToField: ((json['headerToField'] as Map?) ?? const <String, String>{})
          .map((k, v) => MapEntry(k.toString(), v.toString())),
      defaultValues: ((json['defaultValues'] as Map?) ?? const <String, String>{})
          .map((k, v) => MapEntry(k.toString(), v.toString())),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  static const String _prefix = 'spreadsheet_agent.mapping.v1';

  static String storageKey(String templateId, String clientId) {
    return '$_prefix.$templateId.$clientId';
  }
}

class SpreadsheetMappingProfileStore {
  const SpreadsheetMappingProfileStore();

  Future<SpreadsheetMappingProfile?> load({
    required String templateId,
    required String clientId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      SpreadsheetMappingProfile.storageKey(templateId, clientId),
    );
    if ((raw ?? '').trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw!);
      if (decoded is! Map<String, dynamic>) return null;
      return SpreadsheetMappingProfile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SpreadsheetMappingProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SpreadsheetMappingProfile.storageKey(profile.templateId, profile.clientId),
      jsonEncode(profile.toJson()),
    );
  }
}
