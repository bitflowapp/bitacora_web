part of 'start_page_v2.dart';

List<Map<String, dynamic>> _safeJsonDecodeList(String raw) {
  try {
    final value = jsonDecode(raw);
    if (value is List) {
      return value
          .whereType<Map>()
          .map((entry) => entry.cast<String, dynamic>())
          .toList(growable: false);
    }
  } catch (_) {}
  return <Map<String, dynamic>>[];
}

Map<String, dynamic> _safeJsonDecodeMap(String raw) {
  try {
    final value = jsonDecode(raw);
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
  } catch (_) {}
  return <String, dynamic>{};
}

Map<String, String> _mapStringString(Map<String, dynamic> input) {
  final out = <String, String>{};
  input.forEach((key, value) {
    if (value is String) out[key] = value;
    if (value is num) out[key] = value.toString();
  });
  return out;
}

Map<String, int> _mapStringInt(Map<String, dynamic> input) {
  final out = <String, int>{};
  input.forEach((key, value) {
    if (value is int) out[key] = value;
    if (value is num) out[key] = value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) out[key] = parsed;
    }
  });
  return out;
}

class _Folder {
  const _Folder({
    required this.id,
    required this.name,
    required this.createdAtMs,
  });

  final String id;
  final String name;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAtMs': createdAtMs,
      };

  factory _Folder.fromJson(Map<String, dynamic> json) {
    return _Folder(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      createdAtMs: (json['createdAtMs'] is num)
          ? (json['createdAtMs'] as num).toInt()
          : int.tryParse('${json['createdAtMs']}') ?? 0,
    );
  }

  _Folder copyWith({String? name}) => _Folder(
        id: id,
        name: name ?? this.name,
        createdAtMs: createdAtMs,
      );
}

class _AppleToast extends StatefulWidget {
  const _AppleToast({
    required this.message,
    required this.isLight,
  });

  final String message;
  final bool isLight;

  @override
  State<_AppleToast> createState() => _AppleToastState();
}

class _AppleToastState extends State<_AppleToast> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg =
        scheme.inverseSurface.withValues(alpha: widget.isLight ? 0.92 : 0.88);
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 160),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(
                alpha: widget.isLight ? 0.22 : 0.36,
              ),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          widget.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onInverseSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CupertinoToggleRow extends StatelessWidget {
  const _CupertinoToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isLight = CupertinoTheme.of(context).brightness == Brightness.light;
    final theme = Theme.of(context);
    final pal = _ApplePalette(
      isLight: isLight,
      colorScheme: theme.colorScheme,
      scaffold: theme.scaffoldBackgroundColor,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.separator),
        color: pal.group.withValues(alpha: pal.isLight ? 0.75 : 0.35),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: pal.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: pal.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CupertinoInfoBanner extends StatelessWidget {
  const _CupertinoInfoBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.isLight,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = _ApplePalette(
      isLight: isLight,
      colorScheme: theme.colorScheme,
      scaffold: theme.scaffoldBackgroundColor,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: pal.accent.withValues(alpha: 0.08),
        border: Border.all(color: pal.accent.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: pal.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: pal.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    color: pal.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
