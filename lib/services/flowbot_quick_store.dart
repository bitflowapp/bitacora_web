import 'dart:convert';

class FlowBotFavoriteShortcut {
  const FlowBotFavoriteShortcut({
    required this.kind,
    required this.label,
    this.command = '',
    this.quickActionId = '',
    this.requiresValuePrompt = false,
    this.updatedAtMs = 0,
  });

  final String kind;
  final String label;
  final String command;
  final String quickActionId;
  final bool requiresValuePrompt;
  final int updatedAtMs;

  bool get isQuickAction => kind == 'quick_action';

  String get identityKey {
    if (isQuickAction) {
      return 'quick:${quickActionId.trim().toLowerCase()}';
    }
    return 'command:${command.trim().toLowerCase()}';
  }

  FlowBotFavoriteShortcut copyWith({
    String? kind,
    String? label,
    String? command,
    String? quickActionId,
    bool? requiresValuePrompt,
    int? updatedAtMs,
  }) {
    return FlowBotFavoriteShortcut(
      kind: kind ?? this.kind,
      label: label ?? this.label,
      command: command ?? this.command,
      quickActionId: quickActionId ?? this.quickActionId,
      requiresValuePrompt: requiresValuePrompt ?? this.requiresValuePrompt,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'kind': kind,
      'label': label,
      'command': command,
      'quickActionId': quickActionId,
      'requiresValuePrompt': requiresValuePrompt,
      'updatedAtMs': updatedAtMs,
    };
  }

  static FlowBotFavoriteShortcut? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind']?.toString().trim().toLowerCase() ?? '';
    final label = raw['label']?.toString().trim() ?? '';
    final command = raw['command']?.toString().trim() ?? '';
    final quickActionId = raw['quickActionId']?.toString().trim() ?? '';
    final requiresValuePrompt = raw['requiresValuePrompt'] == true;
    final updatedAtMs = int.tryParse(raw['updatedAtMs']?.toString() ?? '') ?? 0;

    if (kind != 'command' && kind != 'quick_action') return null;
    if (kind == 'command' && command.isEmpty) return null;
    if (kind == 'quick_action' && quickActionId.isEmpty) return null;

    return FlowBotFavoriteShortcut(
      kind: kind,
      label:
          label.isEmpty ? (kind == 'command' ? command : quickActionId) : label,
      command: command,
      quickActionId: quickActionId,
      requiresValuePrompt: requiresValuePrompt,
      updatedAtMs: updatedAtMs,
    );
  }
}

class FlowBotQuickStore {
  static Map<String, List<String>> decodeRecentByContext(
    String raw, {
    int limit = 6,
  }) {
    if (raw.trim().isEmpty) return <String, List<String>>{};
    final parsed = jsonDecode(raw);
    if (parsed is! Map) return <String, List<String>>{};
    final result = <String, List<String>>{};
    parsed.forEach((key, value) {
      final contextKey = key.toString().trim();
      if (contextKey.isEmpty || value is! List) return;
      result[contextKey] = normalizeRecentCommands(value, limit: limit);
    });
    return result;
  }

  static String encodeRecentByContext(
    Map<String, List<String>> map, {
    int limit = 6,
  }) {
    final payload = <String, List<String>>{};
    map.forEach((key, value) {
      final contextKey = key.trim();
      if (contextKey.isEmpty) return;
      final cleaned = normalizeRecentCommands(value, limit: limit);
      if (cleaned.isEmpty) return;
      payload[contextKey] = cleaned;
    });
    return jsonEncode(payload);
  }

  static List<String> normalizeRecentCommands(
    Iterable<Object?> raw, {
    int limit = 6,
  }) {
    final cleaned = <String>[];
    for (final item in raw) {
      final text = item.toString().trim();
      if (text.isEmpty) continue;
      if (cleaned
          .any((existing) => existing.toLowerCase() == text.toLowerCase())) {
        continue;
      }
      cleaned.add(text);
      if (cleaned.length >= limit) break;
    }
    return cleaned;
  }

  static List<String> rememberRecent(
    List<String> current,
    String command, {
    int limit = 6,
  }) {
    final text = command.trim();
    if (text.isEmpty) return List<String>.from(current);
    final next = <String>[...current];
    next.removeWhere((item) => item.toLowerCase() == text.toLowerCase());
    next.insert(0, text);
    if (next.length > limit) {
      next.removeRange(limit, next.length);
    }
    return next;
  }

  static Map<String, List<FlowBotFavoriteShortcut>> decodeFavoritesByContext(
    String raw, {
    int limit = 6,
  }) {
    if (raw.trim().isEmpty) {
      return <String, List<FlowBotFavoriteShortcut>>{};
    }
    final parsed = jsonDecode(raw);
    if (parsed is! Map) return <String, List<FlowBotFavoriteShortcut>>{};
    final result = <String, List<FlowBotFavoriteShortcut>>{};
    parsed.forEach((key, value) {
      final contextKey = key.toString().trim();
      if (contextKey.isEmpty || value is! List) return;
      final cleaned = <FlowBotFavoriteShortcut>[];
      for (final item in value) {
        final shortcut = FlowBotFavoriteShortcut.fromJson(item);
        if (shortcut == null) continue;
        if (cleaned
            .any((existing) => existing.identityKey == shortcut.identityKey)) {
          continue;
        }
        cleaned.add(shortcut);
        if (cleaned.length >= limit) break;
      }
      if (cleaned.isNotEmpty) {
        result[contextKey] = cleaned;
      }
    });
    return result;
  }

  static String encodeFavoritesByContext(
    Map<String, List<FlowBotFavoriteShortcut>> map, {
    int limit = 6,
  }) {
    final payload = <String, List<Map<String, Object?>>>{};
    map.forEach((key, value) {
      final contextKey = key.trim();
      if (contextKey.isEmpty) return;
      final cleaned = normalizeFavorites(value, limit: limit);
      if (cleaned.isEmpty) return;
      payload[contextKey] =
          cleaned.map((shortcut) => shortcut.toJson()).toList(growable: false);
    });
    return jsonEncode(payload);
  }

  static List<FlowBotFavoriteShortcut> normalizeFavorites(
    Iterable<FlowBotFavoriteShortcut> raw, {
    int limit = 6,
  }) {
    final cleaned = <FlowBotFavoriteShortcut>[];
    for (final item in raw) {
      if (cleaned.any((existing) => existing.identityKey == item.identityKey)) {
        continue;
      }
      cleaned.add(item);
      if (cleaned.length >= limit) break;
    }
    return cleaned;
  }

  static bool containsFavorite(
    Iterable<FlowBotFavoriteShortcut> favorites,
    FlowBotFavoriteShortcut entry,
  ) {
    return favorites.any((item) => item.identityKey == entry.identityKey);
  }

  static List<FlowBotFavoriteShortcut> toggleFavorite(
    List<FlowBotFavoriteShortcut> current,
    FlowBotFavoriteShortcut entry, {
    int limit = 6,
    required int nowMs,
  }) {
    final next = <FlowBotFavoriteShortcut>[...current];
    final existingIndex =
        next.indexWhere((item) => item.identityKey == entry.identityKey);
    if (existingIndex >= 0) {
      next.removeAt(existingIndex);
      return normalizeFavorites(next, limit: limit);
    }
    next.insert(0, entry.copyWith(updatedAtMs: nowMs));
    return normalizeFavorites(next, limit: limit);
  }
}
