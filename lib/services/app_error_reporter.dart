import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_error.dart';

class AppErrorEvent {
  const AppErrorEvent({
    required this.id,
    required this.at,
    required this.flow,
    required this.kind,
    required this.userMessage,
    required this.technicalDetail,
    this.operation,
    this.code,
  });

  final String id;
  final DateTime at;
  final AppErrorFlow flow;
  final AppErrorKind kind;
  final String userMessage;
  final String technicalDetail;
  final String? operation;
  final String? code;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'at': at.toIso8601String(),
        'flow': flow.name,
        'kind': kind.name,
        'userMessage': userMessage,
        'technicalDetail': technicalDetail,
        if ((operation ?? '').trim().isNotEmpty) 'operation': operation,
        if ((code ?? '').trim().isNotEmpty) 'code': code,
      };

  static AppErrorEvent? fromJson(Map<String, dynamic> raw) {
    try {
      final id = (raw['id'] ?? '').toString().trim();
      final at = DateTime.tryParse((raw['at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final flow = _parseFlow((raw['flow'] ?? '').toString());
      final kind = _parseKind((raw['kind'] ?? '').toString());
      final userMessage = (raw['userMessage'] ?? '').toString().trim();
      final technicalDetail = (raw['technicalDetail'] ?? '').toString().trim();
      if (id.isEmpty || userMessage.isEmpty) return null;
      return AppErrorEvent(
        id: id,
        at: at,
        flow: flow,
        kind: kind,
        userMessage: userMessage,
        technicalDetail: technicalDetail,
        operation: (raw['operation'] ?? '').toString().trim(),
        code: (raw['code'] ?? '').toString().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  static AppErrorFlow _parseFlow(String raw) {
    for (final value in AppErrorFlow.values) {
      if (value.name == raw) return value;
    }
    return AppErrorFlow.load;
  }

  static AppErrorKind _parseKind(String raw) {
    for (final value in AppErrorKind.values) {
      if (value.name == raw) return value;
    }
    return AppErrorKind.unknown;
  }
}

abstract class AppErrorReporterStorage {
  Future<List<AppErrorEvent>> load();
  Future<void> save(List<AppErrorEvent> events);
}

class SharedPrefsAppErrorReporterStorage implements AppErrorReporterStorage {
  const SharedPrefsAppErrorReporterStorage({
    this.storageKey = 'bitflow.app_error_events.v1',
  });

  final String storageKey;

  @override
  Future<List<AppErrorEvent>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const <AppErrorEvent>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <AppErrorEvent>[];

    final out = <AppErrorEvent>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final parsed = AppErrorEvent.fromJson(item.cast<String, dynamic>());
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  @override
  Future<void> save(List<AppErrorEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
        events.map((event) => event.toJson()).toList(growable: false));
    await prefs.setString(storageKey, payload);
  }
}

class MemoryAppErrorReporterStorage implements AppErrorReporterStorage {
  List<AppErrorEvent> _events = <AppErrorEvent>[];

  @override
  Future<List<AppErrorEvent>> load() async {
    return List<AppErrorEvent>.from(_events);
  }

  @override
  Future<void> save(List<AppErrorEvent> events) async {
    _events = List<AppErrorEvent>.from(events);
  }
}

class AppErrorReporter {
  AppErrorReporter({
    AppErrorReporterStorage? storage,
    int capacity = 50,
  })  : _storage = storage ?? const SharedPrefsAppErrorReporterStorage(),
        _capacity = capacity > 0 ? capacity : 50;

  static final AppErrorReporter I = AppErrorReporter();

  final AppErrorReporterStorage _storage;
  final int _capacity;
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final List<AppErrorEvent> _events = <AppErrorEvent>[];
  final List<AppErrorEvent> _pendingBeforeInit = <AppErrorEvent>[];
  final List<AppErrorEvent> _memoryFallback = <AppErrorEvent>[];

  Future<void>? _initFuture;
  Future<void> _persistQueue = Future<void>.value();
  bool _initialized = false;
  bool _usingMemoryFallback = false;
  int _seed = 0;

  bool get isUsingMemoryFallback => _usingMemoryFallback;
  int get capacity => _capacity;

  Future<void> init() {
    _initFuture ??= _loadFromStorage();
    return _initFuture!;
  }

  List<AppErrorEvent> recent({int limit = 50}) {
    final bounded = limit <= 0 ? _events.length : limit;
    final start = _events.length - bounded;
    final safeStart = start < 0 ? 0 : start;
    final tail = _events.sublist(safeStart);
    return tail.reversed.toList(growable: false);
  }

  void record(
    AppError appError, {
    required String operation,
    StackTrace? stackTrace,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final event = AppErrorEvent(
      id: '${at.microsecondsSinceEpoch}_${_seed++}',
      at: at,
      flow: appError.flow,
      kind: appError.kind,
      userMessage: _redactAndClip(appError.userMessage, maxChars: 420),
      technicalDetail: _buildTechnicalDetail(
        appError,
        operation: operation,
        stackTrace: stackTrace,
      ),
      operation: _redactAndClip(operation, maxChars: 120),
      code: _redactAndClip(appError.code ?? '', maxChars: 80),
    );

    if (!_initialized) {
      _pushInto(_pendingBeforeInit, event);
      unawaited(init());
      return;
    }

    _pushInto(_events, event);
    _schedulePersist();
    revision.value++;
  }

  Future<void> clear() async {
    await init();
    _events.clear();
    _pendingBeforeInit.clear();
    _memoryFallback.clear();
    _schedulePersist();
    revision.value++;
  }

  Future<void> flush() async {
    await init();
    await _persistQueue;
  }

  Future<void> _loadFromStorage() async {
    try {
      final loaded = await _storage.load();
      _events
        ..clear()
        ..addAll(loaded);
      _trim(_events);
      _usingMemoryFallback = false;
    } catch (_) {
      _usingMemoryFallback = true;
      _events
        ..clear()
        ..addAll(_memoryFallback);
      _trim(_events);
    }

    if (_pendingBeforeInit.isNotEmpty) {
      for (final event in _pendingBeforeInit) {
        _pushInto(_events, event);
      }
      _pendingBeforeInit.clear();
      _schedulePersist();
    }

    _initialized = true;
    revision.value++;
  }

  void _schedulePersist() {
    final snapshot = List<AppErrorEvent>.from(_events);
    _persistQueue = _persistQueue.then((_) => _persistSnapshot(snapshot));
  }

  Future<void> _persistSnapshot(List<AppErrorEvent> snapshot) async {
    if (_usingMemoryFallback) {
      _memoryFallback
        ..clear()
        ..addAll(snapshot);
      _trim(_memoryFallback);
      return;
    }

    try {
      await _storage.save(snapshot);
    } catch (_) {
      _usingMemoryFallback = true;
      _memoryFallback
        ..clear()
        ..addAll(snapshot);
      _trim(_memoryFallback);
    }
  }

  void _pushInto(List<AppErrorEvent> target, AppErrorEvent event) {
    target.add(event);
    _trim(target);
  }

  void _trim(List<AppErrorEvent> target) {
    if (target.length <= _capacity) return;
    target.removeRange(0, target.length - _capacity);
  }

  String _buildTechnicalDetail(
    AppError appError, {
    required String operation,
    StackTrace? stackTrace,
  }) {
    final parts = <String>[];
    final op = operation.trim();
    if (op.isNotEmpty) parts.add('op=$op');

    final code = (appError.code ?? '').trim();
    if (code.isNotEmpty) parts.add('code=$code');

    final technical = appError.technicalMessage.trim();
    if (technical.isNotEmpty) parts.add('msg=$technical');

    final stack = stackTrace?.toString().trim() ?? '';
    if (stack.isNotEmpty) {
      final lines = stack
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .take(4)
          .join('\n');
      if (lines.isNotEmpty) parts.add(lines);
    }

    return _redactAndClip(parts.join('\n'), maxChars: 1600);
  }

  String _redactAndClip(String raw, {required int maxChars}) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    text = text.replaceAllMapped(
      RegExp(
        r'\b(api[_-]?key|token|secret|password|authorization)\b\s*[:=]\s*([^\s,;]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=[redacted]',
    );

    text = text.replaceAllMapped(
      RegExp(
        r'bearer\s+[A-Za-z0-9\-\._~\+\/=]+',
        caseSensitive: false,
      ),
      (_) => 'bearer [redacted]',
    );

    text = text.replaceAllMapped(
      RegExp(
        r'([?&](?:token|api[_-]?key|auth|authorization|password|secret)=)[^&\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[redacted]',
    );

    text = text.replaceAll(
      RegExp(r'[A-Za-z]:\\[^\s"]+'),
      '[redacted-path]',
    );
    text = text.replaceAll(
      RegExp(r'file://[^\s"]+'),
      '[redacted-path]',
    );
    text = text.replaceAllMapped(
      RegExp(r'/(Users|home|private|var|data)/[^\s"]+'),
      (match) => '/${match.group(1)}/[redacted]',
    );

    if (text.length > maxChars) {
      text = '${text.substring(0, maxChars)}...';
    }
    return text;
  }
}
