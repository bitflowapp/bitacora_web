// lib/widgets/speech_mic_button.dart
// Botón de micrófono con animación naranja y ondas sonoras.
// Integra SpeechPort y soporta "fila activa" para dictado contextual.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/speech_port.dart';

class SpeechMicButton extends StatefulWidget {
  const SpeechMicButton({
    super.key,
    required this.port,
    this.onResult,
    this.onPartial,
    this.preferredLocale,
    this.label,
    this.enabled = true,
    this.activeRowIndex,
    this.rowLabelBuilder,
  });

  /// Implementación concreta (IO/Web) de SpeechPort.
  final SpeechPort port;

  /// Texto final reconocido.
  final ValueChanged<String>? onResult;

  /// Texto parcial mientras dicta (opcional).
  final ValueChanged<String>? onPartial;

  /// Locale preferido (ej: 'es_AR').
  final String? preferredLocale;

  /// Etiqueta fija bajo el botón (si no se usa rowLabelBuilder).
  final String? label;

  /// Si es false, el botón se ve deshabilitado y no arranca dictado.
  final bool enabled;

  /// Fila actualmente seleccionada (0-based). Puede ser null si no hay selección.
  final int? activeRowIndex;

  /// Si se provee, construye la etiqueta usando la fila activa.
  /// Ej: (row) => 'Dictar en fila ${row + 1}'.
  final String Function(int row)? rowLabelBuilder;

  @override
  State<SpeechMicButton> createState() => _SpeechMicButtonState();
}

class _SpeechMicButtonState extends State<SpeechMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  bool _ready = false;
  bool _initializing = false;
  bool _listening = false;
  double _level = 0; // 0–1 aprox

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _pulseCtrl.addStatusListener((status) {
      if (!_listening) return;
      if (status == AnimationStatus.completed) {
        _pulseCtrl.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _pulseCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureReady() async {
    if (_ready || _initializing) return;
    _initializing = true;
    try {
      final ok =
          await widget.port.init(preferredLocale: widget.preferredLocale);
      if (!mounted) return;
      _ready = ok;
      if (!ok) {
        _showSnack('No se pudo inicializar el micrófono.');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error al iniciar el micrófono.');
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      } else {
        _initializing = false;
      }
    }
  }

  Future<void> _startListening() async {
    if (_listening) return;
    if (!widget.enabled || widget.activeRowIndex == null) {
      _showSnack('Seleccioná una fila antes de dictar.');
      return;
    }

    await _ensureReady();
    if (!_ready || !mounted) return;

    setState(() {
      _listening = true;
      _level = 0;
    });

    _pulseCtrl
      ..reset()
      ..forward();

    try {
      final text = await widget.port.listenOnce(
        localeId: widget.preferredLocale,
        partial: (partialText) {
          if (!mounted) return;
          widget.onPartial?.call(partialText);
        },
        level: (rawLevel) {
          if (!mounted) return;
          final clamped = rawLevel.clamp(0.0, 1.0);
          setState(() {
            _level = clamped;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _listening = false;
        _level = 0;
      });
      _pulseCtrl.stop();

      final finalText = text?.trim();
      if (finalText != null && finalText.isNotEmpty) {
        widget.onResult?.call(finalText);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _level = 0;
      });
      _pulseCtrl.stop();
      _showSnack('Hubo un problema con el dictado.');
    }
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    try {
      await widget.port.stop();
    } catch (_) {
      // Algunos motores no soportan stop; ignoramos.
    }
    if (!mounted) return;
    setState(() {
      _listening = false;
      _level = 0;
    });
    _pulseCtrl.stop();
  }

  void _onTap() {
    if (_initializing) return;
    if (_listening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _showSnack(String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2000),
        ),
      );
  }

  String _effectiveLabel(bool isRecording) {
    if (!widget.enabled || widget.activeRowIndex == null) {
      return 'Seleccioná una fila para dictar';
    }
    if (widget.rowLabelBuilder != null) {
      return widget.rowLabelBuilder!(widget.activeRowIndex!);
    }
    if (widget.label != null) return widget.label!;
    return isRecording ? 'Grabando… toca para detener' : 'Tocar para dictar';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final isRecording = _listening;
    const orange = Color(0xFFFF9800);

    final labelText = _effectiveLabel(isRecording);
    final isDisabled = !widget.enabled || widget.activeRowIndex == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulseAnim,
          child: GestureDetector(
            onTap: isDisabled ? null : _onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDisabled
                    ? LinearGradient(
                        colors: [
                          c.surfaceContainerHighest.withValues(alpha: 0.6),
                          c.surface.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : isRecording
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFFFD180),
                              Color(0xFFFFA726),
                              Color(0xFFFF9800),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              c.surfaceContainerHighest,
                              c.surface,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                boxShadow: isRecording
                    ? [
                        BoxShadow(
                          color: orange.withValues(alpha: 0.55),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: isDisabled
                    ? c.onSurface.withValues(alpha: 0.35)
                    : isRecording
                        ? Colors.white
                        : c.primary,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedOpacity(
          opacity: isRecording ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: _Waveform(
            level: _level,
            barColor: orange,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          labelText,
          style: t.textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.level,
    required this.barColor,
  });

  final double level;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final clamped = level.clamp(0.0, 1.0);
    const bars = 16;
    const baseHeight = 6.0;
    const extra = 20.0;

    return SizedBox(
      height: baseHeight + extra,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(bars, (i) {
          final wavePhase = (i / (bars - 1)) * math.pi;
          final factor = 0.35 + 0.65 * math.sin(wavePhase);
          final h = baseHeight + extra * clamped * factor;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }),
      ),
    );
  }
}
