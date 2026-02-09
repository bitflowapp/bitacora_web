// lib/services/sound_bank_stub.dart
import 'sound_bank.dart';

/// Implementación silenciosa para plataformas no Web.
class _SilentSoundBank implements SoundBank {
  const _SilentSoundBank();

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

  @override
  Future<void> click() async {
    // Sin sonido en móvil/escritorio (por ahora).
  }

  @override
  Future<void> dispose() async {
    // Nada que liberar.
  }
}

/// Creador concreto usado por `sound_bank.dart`.
SoundBank createSoundBank() => const _SilentSoundBank();
