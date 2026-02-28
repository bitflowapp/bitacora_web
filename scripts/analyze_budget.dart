import 'dart:io';

Future<void> main(List<String> args) async {
  final baseline = _readBaseline(args);
  final analyzeArgs = <String>[
    'analyze',
    '--no-fatal-infos',
    '--no-fatal-warnings',
  ];

  stdout.writeln('Running: flutter ${analyzeArgs.join(' ')}');
  final result = await Process.run(
    'flutter',
    analyzeArgs,
    runInShell: true,
  );

  final combined = '${result.stdout ?? ''}\n${result.stderr ?? ''}';
  stdout.write(combined);

  final diagnostics = _collectDiagnostics(combined);
  final total = diagnostics.values.fold<int>(0, (sum, count) => sum + count);

  stdout.writeln('\nAnalyze budget summary');
  stdout.writeln('Total issues: $total');
  stdout.writeln('Baseline: $baseline');
  stdout.writeln('Top 5 diagnostics:');

  final sorted = diagnostics.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });

  if (sorted.isEmpty) {
    stdout.writeln('- (none)');
  } else {
    for (final entry in sorted.take(5)) {
      stdout.writeln('- ${entry.key}: ${entry.value}');
    }
  }

  if (result.exitCode != 0 && total == 0) {
    stderr.writeln(
      'Analyze command failed before issue parsing (exit ${result.exitCode}).',
    );
    exit(result.exitCode);
  }

  if (total > baseline) {
    stderr.writeln(
      'Analyze budget exceeded: total $total is above baseline $baseline.',
    );
    exit(1);
  }

  stdout.writeln('Analyze budget check passed.');
}

int _readBaseline(List<String> args) {
  const fallback = 100;
  final env = Platform.environment['ANALYZE_BASELINE'];
  if (env != null) {
    final parsed = int.tryParse(env.trim());
    if (parsed != null) return parsed;
  }

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--baseline' && i + 1 < args.length) {
      final parsed = int.tryParse(args[i + 1].trim());
      if (parsed != null) return parsed;
    }
    if (arg.startsWith('--baseline=')) {
      final parsed = int.tryParse(arg.substring('--baseline='.length).trim());
      if (parsed != null) return parsed;
    }
  }

  return fallback;
}

Map<String, int> _collectDiagnostics(String output) {
  final issueLine = RegExp(
    r'^\s*(?:info|warning|error) - .+ - ([a-z0-9_]+)$',
    multiLine: true,
  );
  final counts = <String, int>{};
  for (final match in issueLine.allMatches(output)) {
    final code = match.group(1);
    if (code == null || code.isEmpty) continue;
    counts.update(code, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
}
