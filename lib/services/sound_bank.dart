// lib/services/sound_bank.dart
// Selector de implementación de efectos de sonido según plataforma.
//
// - Web: usa `sound_bank_web.dart`.
// - Otras plataformas: usa `sound_bank_stub.dart`.

import 'sound_bank_stub.dart'
if (dart.library.html) 'sound_bank_web.dart' as sound_impl;

/// Abstracción mínima para reproducir efectos de sonido de la app.
abstract class SoundBank {
  /// Sonido corto de tap / click de interfaz.
  Future<void> click();

  /// Libera recursos asociados (si los hay).
  Future<void> dispose();
}

/// Devuelve la implementación concreta de [SoundBank]
/// adecuada para la plataforma actual.
SoundBank getSoundBank() => sound_impl.createSoundBank();
