// lib/widgets/typing_fx.dart
import 'package:flutter/material.dart';
import '../services/sound_bank.dart';

class TypingFx {
  DateTime? _last;
  final Duration minGap;
  final double gain;

  TypingFx({this.minGap = const Duration(milliseconds: 90), this.gain = 0.6});

  void click() {
    final now = DateTime.now();
    if (_last == null || now.difference(_last!) > minGap) {
      SoundBank.instance.play(Sfx.type, gain: gain);
      _last = now;
    }
  }
}

// Ejemplo de uso dentro de un StatefulWidget del editor:
class _CellEditorState extends State<StatefulWidget> {
  final _fx = TypingFx();

  @override
  void initState() {
    super.initState();
    // Precarga de audio
    unawaited(SoundBank.instance.init());
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      onChanged: (_) => _fx.click(), // sonido de tipeo con throttle
    );
  }
}
