import 'dart:convert';

class FlowBotMacroPreset {
  const FlowBotMacroPreset({
    required this.name,
    required this.command,
  });

  final String name;
  final String command;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'command': command,
      };

  static FlowBotMacroPreset? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    final name = (map['name'] ?? '').toString().trim();
    final command = (map['command'] ?? '').toString().trim();
    if (name.isEmpty || command.isEmpty) return null;
    return FlowBotMacroPreset(name: name, command: command);
  }
}

class FlowBotMacroStore {
  static String encode(List<FlowBotMacroPreset> presets) {
    return jsonEncode(presets.map((preset) => preset.toJson()).toList());
  }

  static List<FlowBotMacroPreset> decode(
    String raw, {
    int maxItems = 24,
  }) {
    final text = raw.trim();
    if (text.isEmpty) return const <FlowBotMacroPreset>[];
    final decoded = jsonDecode(text);
    if (decoded is! List) return const <FlowBotMacroPreset>[];
    final out = <FlowBotMacroPreset>[];
    for (final item in decoded) {
      final preset = FlowBotMacroPreset.fromJson(item);
      if (preset == null) continue;
      out.add(preset);
      if (out.length >= maxItems) break;
    }
    return out;
  }
}
