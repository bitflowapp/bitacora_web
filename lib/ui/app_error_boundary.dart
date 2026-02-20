import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppErrorBoundary extends StatefulWidget {
  const AppErrorBoundary({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppErrorBoundary> createState() => AppErrorBoundaryState();
}

class AppErrorBoundaryState extends State<AppErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  bool get hasError => _error != null;

  void capture(Object error, [StackTrace? stackTrace]) {
    if (!mounted) return;
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });
  }

  void clear() {
    if (!mounted) return;
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error == null) return widget.child;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0x22000000)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BitFlow se recupero de un error',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'La app sigue disponible. Puedes volver al inicio y continuar.',
                          style: TextStyle(height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          error.toString(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF44444A),
                            fontSize: 13,
                          ),
                        ),
                        if (kDebugMode && _stackTrace != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _stackTrace.toString(),
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF66666E),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton(
                              onPressed: clear,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
