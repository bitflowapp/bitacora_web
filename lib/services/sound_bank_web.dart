// Web: reproduce assets/sfx/type.wav usando <audio>.
import 'dart:html' as html;
import 'sound_bank.dart';

class _SoundBankWeb implements SoundBank {
  final Map<String, html.AudioElement> _cache = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> play(Sfx sfx, {double gain = 1.0}) async {
    switch (sfx) {
      case Sfx.type:
        await click();
        return;
    }
  }

  Future<void> _play(String path) async {
    final el = _cache[path] ?? (html.AudioElement(path)..preload = 'auto');
    _cache[path] = el;
    el.currentTime = 0;
    await el.play();
  }

  @override
  Future<void> click() => _play('assets/sfx/type.wav');

  @override
  Future<void> dispose() async {
    for (final a in _cache.values) {
      a.pause();
      a.src = '';
      a.load();
    }
    _cache.clear();
  }
}

SoundBank createSoundBank() => _SoundBankWeb();
