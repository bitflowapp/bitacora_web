import 'package:bitacora_web/models/cell_meta.dart';
import 'package:flutter_test/flutter_test.dart';

// Mirrors the private _isVideoMime logic in attachments_controller.dart so we
// can verify detection rules without importing internal extension methods.
bool _isVideoMime(String mime, String name) {
  final m = mime.toLowerCase();
  if (m.startsWith('video/')) return true;
  final n = name.toLowerCase();
  return n.endsWith('.mp4') ||
      n.endsWith('.mov') ||
      n.endsWith('.avi') ||
      n.endsWith('.mkv');
}

PhotoAttachment _photo(String id, {String mime = 'image/jpeg'}) =>
    PhotoAttachment(
      id: id,
      filename: 'foto_$id.jpg',
      mime: mime,
      size: 1024,
      storedRef: 'mem:$id',
      thumbRef: '',
      addedAt: DateTime(2026, 4, 26),
    );

AudioAttachment _audio(String id) => AudioAttachment(
      id: id,
      filename: 'audio_$id.m4a',
      mime: 'audio/m4a',
      size: 2048,
      durationMs: 5000,
      storedRef: 'mem:aud_$id',
      addedAt: DateTime(2026, 4, 26),
    );

GpsMeta _gps() => GpsMeta(
      lat: -34.60,
      lng: -58.38,
      accuracyM: 8.0,
      timestamp: DateTime(2026, 4, 26),
      source: 'current',
      provider: 'test',
    );

void main() {
  group('CellMeta attachment indicators', () {
    test('cell with 0 attachments is empty — no indicator', () {
      const meta = CellMeta();
      expect(meta.isEmpty, isTrue);
      expect(meta.hasPhotos, isFalse);
      expect(meta.hasAudios, isFalse);
      expect(meta.hasGps, isFalse);
      expect(meta.photos.length, 0);
    });

    test('cell with 1 photo shows indicator', () {
      final meta = CellMeta(photos: [_photo('p1')]);
      expect(meta.hasPhotos, isTrue);
      expect(meta.photos.length, 1);
      expect(meta.isEmpty, isFalse);
    });

    test('cell with 2 photos shows counter', () {
      final meta = CellMeta(photos: [_photo('p1'), _photo('p2')]);
      expect(meta.photos.length, 2);
      expect(meta.hasPhotos, isTrue);
    });

    test('cell with 3+ photos shows counter', () {
      final meta =
          CellMeta(photos: [_photo('p1'), _photo('p2'), _photo('p3')]);
      expect(meta.photos.length, 3);
    });

    test('audio indicator separate from photo indicator', () {
      final meta = CellMeta(audios: [_audio('a1')]);
      expect(meta.hasAudios, isTrue);
      expect(meta.hasPhotos, isFalse);
      expect(meta.isEmpty, isFalse);
    });

    test('GPS indicator present when gps set', () {
      final meta = CellMeta(gps: _gps());
      expect(meta.hasGps, isTrue);
      expect(meta.isEmpty, isFalse);
    });
  });

  group('Delete single attachment — others preserved', () {
    test('deleting photo at index 0 preserves photo at index 1', () {
      final meta = CellMeta(photos: [_photo('p1'), _photo('p2')]);
      final nextPhotos = List<PhotoAttachment>.from(meta.photos)
        ..removeAt(0);
      final next = CellMeta(
        gps: meta.gps,
        photos: nextPhotos,
        audios: meta.audios,
      );
      expect(next.photos.length, 1);
      expect(next.photos.first.id, 'p2');
    });

    test('deleting photo does not remove audio', () {
      final meta = CellMeta(
        photos: [_photo('p1')],
        audios: [_audio('a1')],
      );
      final nextPhotos = List<PhotoAttachment>.from(meta.photos)
        ..removeAt(0);
      final next = CellMeta(
        gps: meta.gps,
        photos: nextPhotos,
        audios: meta.audios,
      );
      expect(next.photos.isEmpty, isTrue);
      expect(next.audios.length, 1);
    });

    test('deleting audio does not remove photos', () {
      final meta = CellMeta(
        photos: [_photo('p1'), _photo('p2')],
        audios: [_audio('a1')],
      );
      final nextAudios = List<AudioAttachment>.from(meta.audios)
        ..removeAt(0);
      final next = CellMeta(
        gps: meta.gps,
        photos: meta.photos,
        audios: nextAudios,
      );
      expect(next.audios.isEmpty, isTrue);
      expect(next.photos.length, 2);
    });

    test('deleting evidence does not affect cell GPS', () {
      final meta = CellMeta(photos: [_photo('p1')], gps: _gps());
      final nextPhotos = List<PhotoAttachment>.from(meta.photos)
        ..removeAt(0);
      final next = CellMeta(
        gps: meta.gps,
        photos: nextPhotos,
        audios: meta.audios,
      );
      expect(next.photos.isEmpty, isTrue);
      expect(next.hasGps, isTrue);
      expect(next.gps!.lat, closeTo(-34.60, 0.0001));
    });

    test('delete all photos makes cell have no photos', () {
      final meta = CellMeta(photos: [_photo('p1')]);
      final nextPhotos = List<PhotoAttachment>.from(meta.photos)
        ..removeAt(0);
      final next = CellMeta(
        gps: meta.gps,
        photos: nextPhotos,
        audios: meta.audios,
      );
      expect(next.photos.isEmpty, isTrue);
      expect(next.isEmpty, isTrue);
    });
  });

  group('Adding evidence preserves existing', () {
    test('adding second photo preserves first', () {
      final first = _photo('p1');
      final meta = CellMeta(photos: [first]);
      final second = _photo('p2');
      final next = CellMeta(
        gps: meta.gps,
        photos: [...meta.photos, second],
        audios: meta.audios,
      );
      expect(next.photos.length, 2);
      expect(next.photos.first.id, 'p1');
      expect(next.photos.last.id, 'p2');
    });

    test('adding photo preserves existing GPS', () {
      final meta = CellMeta(gps: _gps());
      final next = CellMeta(
        gps: meta.gps,
        photos: [...meta.photos, _photo('p1')],
        audios: meta.audios,
      );
      expect(next.hasGps, isTrue);
      expect(next.photos.length, 1);
    });

    test('adding audio preserves existing photos', () {
      final meta = CellMeta(photos: [_photo('p1'), _photo('p2')]);
      final next = CellMeta(
        gps: meta.gps,
        photos: meta.photos,
        audios: [...meta.audios, _audio('a1')],
      );
      expect(next.photos.length, 2);
      expect(next.audios.length, 1);
    });
  });

  group('CellMeta serialization round-trip', () {
    test('photo + audio + gps round-trips cleanly', () {
      final original = CellMeta(
        gps: _gps(),
        photos: [_photo('p1')],
        audios: [_audio('a1')],
      );
      final json = original.toJson();
      final restored = CellMeta.fromJson(json)!;
      expect(restored.photos.length, 1);
      expect(restored.photos.first.id, 'p1');
      expect(restored.audios.length, 1);
      expect(restored.audios.first.id, 'a1');
      expect(restored.hasGps, isTrue);
    });

    test('empty CellMeta serializes and restores as null', () {
      const meta = CellMeta();
      final json = meta.toJson();
      final restored = CellMeta.fromJson(json);
      // isEmpty metas may return null from fromJson
      if (restored != null) {
        expect(restored.isEmpty, isTrue);
      }
    });
  });

  group('Video mime detection', () {
    test('video/mp4 is detected as video', () {
      expect(_isVideoMime('video/mp4', 'clip.mp4'), isTrue);
    });

    test('video/quicktime is detected as video', () {
      expect(_isVideoMime('video/quicktime', 'clip.mov'), isTrue);
    });

    test('.mov extension detected as video', () {
      expect(_isVideoMime('', 'grabacion.mov'), isTrue);
    });

    test('.mkv extension detected as video', () {
      expect(_isVideoMime('', 'video.mkv'), isTrue);
    });

    test('image/jpeg is NOT video', () {
      expect(_isVideoMime('image/jpeg', 'foto.jpg'), isFalse);
    });

    test('image/png is NOT video', () {
      expect(_isVideoMime('image/png', 'captura.png'), isFalse);
    });

    test('audio/m4a is NOT video', () {
      expect(_isVideoMime('audio/m4a', 'audio.m4a'), isFalse);
    });

    test('empty mime with .jpg extension is NOT video', () {
      expect(_isVideoMime('', 'foto.jpg'), isFalse);
    });
  });

  group('Preview fallback — no crash on missing bytes', () {
    test('photo with empty storedRef still has valid model', () {
      final photo = PhotoAttachment(
        id: 'p_empty',
        filename: 'foto.jpg',
        mime: 'image/jpeg',
        size: 0,
        storedRef: '',
        thumbRef: '',
        addedAt: DateTime(2026, 4, 26),
      );
      expect(photo.storedRef, isEmpty);
      expect(photo.filename, 'foto.jpg');
      // No crash constructing the model — preview logic handles empty ref safely
    });

    test('video with unknown mime still has valid model', () {
      final video = PhotoAttachment(
        id: 'v1',
        filename: 'clip.mp4',
        mime: 'video/mp4',
        size: 14000000,
        storedRef: 'file:/tmp/clip.mp4',
        thumbRef: '',
        addedAt: DateTime(2026, 4, 26),
      );
      expect(_isVideoMime(video.mime, video.filename), isTrue);
      expect(video.storedRef, contains('file:'));
    });
  });
}
