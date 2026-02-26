// lib/widgets/typing_fx.dart
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
