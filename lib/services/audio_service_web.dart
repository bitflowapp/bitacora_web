import 'dart:async';
import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'dart:web_audio' as wa; // ignore: avoid_web_libraries_in_flutter

import 'audio_service.dart';

class AudioServiceImpl implements AudioService {
  bool _recording = false;
  DateTime? _startedAt;

  html.MediaRecorder? _mediaRecorder;
  html.MediaStream? _stream;
  StreamSubscription<html.BlobEvent>? _dataSub;
  final List<html.Blob> _chunks = <html.Blob>[];

  bool _useWebAudio = false;
  wa.AudioContext? _audioContext;
  wa.MediaStreamAudioSourceNode? _sourceNode;
  wa.ScriptProcessorNode? _processor;
  final List<Float32List> _pcmChunks = <Float32List>[];
  int _sampleRate = 44100;

  static const html.EventStreamProvider<html.BlobEvent> _dataAvailableEvent =
      html.EventStreamProvider<html.BlobEvent>('dataavailable');
  static const html.EventStreamProvider<html.Event> _stopEvent =
      html.EventStreamProvider<html.Event>('stop');

  @override
  Future<bool> isSupported() async {
    try {
      final media = html.window.navigator.mediaDevices;
      if (media == null) return false;
      if (_supportedMimeType() != null) return true;
      return _supportsWebAudio();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      final perms = (html.window.navigator as dynamic).permissions;
      if (perms != null) {
        final status = await perms.query({'name': 'microphone'});
        final state = (status as dynamic).state?.toString() ?? '';
        return state == 'granted';
      }
    } catch (_) {}
    return true;
  }

  @override
  Future<void> startRecording({required String sheetId}) async {
    if (_recording) return;
    final media = html.window.navigator.mediaDevices;
    if (media == null) {
      throw Exception('MediaDevices no disponible.');
    }

    _stream = await media.getUserMedia({'audio': true});
    final mime = _supportedMimeType();
    _chunks.clear();
    _pcmChunks.clear();

    if (mime != null) {
      _useWebAudio = false;
      final recorder = html.MediaRecorder(_stream!, {'mimeType': mime});
      _mediaRecorder = recorder;
      await _dataSub?.cancel();
      _dataSub = _dataAvailableEvent.forTarget(recorder).listen((event) {
        final data = event.data;
        if (data != null && data.size > 0) {
          _chunks.add(data);
        }
      });
      recorder.start();
    } else {
      _useWebAudio = true;
      await _startWebAudioFallback(_stream!);
    }

    _recording = true;
    _startedAt = DateTime.now();
  }

  @override
  Future<RecordedAudio?> stopRecording() async {
    if (!_recording) return null;
    _recording = false;

    final started = _startedAt;
    _startedAt = null;

    if (_useWebAudio) {
      return _stopWebAudio(started);
    }
    return _stopMediaRecorder(started);
  }

  @override
  Future<void> dispose() async {
    try {
      if (_recording) {
        await stopRecording();
      }
    } catch (_) {}

    try {
      await _dataSub?.cancel();
    } catch (_) {}
    _dataSub = null;

    try {
      _mediaRecorder = null;
      _chunks.clear();
    } catch (_) {}

    try {
      _processor?.disconnect();
    } catch (_) {}
    try {
      _sourceNode?.disconnect();
    } catch (_) {}
    try {
      await _audioContext?.close();
    } catch (_) {}

    try {
      _stream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}

    _processor = null;
    _sourceNode = null;
    _audioContext = null;
    _stream = null;
  }

  String? _supportedMimeType() {
    try {
      if (html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
        return 'audio/webm;codecs=opus';
      }
      if (html.MediaRecorder.isTypeSupported('audio/webm')) return 'audio/webm';
      if (html.MediaRecorder.isTypeSupported('audio/ogg;codecs=opus')) {
        return 'audio/ogg;codecs=opus';
      }
      if (html.MediaRecorder.isTypeSupported('audio/ogg')) return 'audio/ogg';
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _supportsWebAudio() {
    try {
      final ctx = wa.AudioContext();
      ctx.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startWebAudioFallback(html.MediaStream stream) async {
    final ctx = wa.AudioContext();
    _audioContext = ctx;
    final rate = ctx.sampleRate ?? 44100;
    _sampleRate = rate.toInt();

    final source = ctx.createMediaStreamSource(stream);
    _sourceNode = source;

    final processor = ctx.createScriptProcessor(4096, 1, 1);
    _processor = processor;
    _pcmChunks.clear();

    processor.onAudioProcess.listen((event) {
      final inputBuffer = event.inputBuffer;
      final outputBuffer = event.outputBuffer;
      if (inputBuffer == null || outputBuffer == null) return;
      final input = inputBuffer.getChannelData(0);
      _pcmChunks.add(Float32List.fromList(input));
      final output = outputBuffer.getChannelData(0);
      for (int i = 0; i < output.length; i++) {
        output[i] = 0;
      }
    });

    source.connectNode(processor);
    final destination = ctx.destination;
    if (destination != null) {
      processor.connectNode(destination);
    }
  }

  Future<RecordedAudio?> _stopMediaRecorder(DateTime? started) async {
    final recorder = _mediaRecorder;
    if (recorder == null) return null;

    final stopFuture = _stopEvent.forTarget(recorder).first;
    recorder.stop();
    await stopFuture;

    await _dataSub?.cancel();
    _dataSub = null;

    final mime = recorder.mimeType ?? _supportedMimeType() ?? 'audio/webm';
    final blob = html.Blob(_chunks, mime);
    _chunks.clear();

    final bytes = await _blobToBytes(blob);
    if (bytes == null || bytes.isEmpty) return null;

    _mediaRecorder = null;
    _stream?.getTracks().forEach((t) => t.stop());
    _stream = null;

    final duration = started == null
        ? Duration.zero
        : DateTime.now().difference(started);

    return RecordedAudio(
      fileName: _fileNameForMime(mime),
      mime: mime,
      duration: duration,
      bytes: bytes,
    );
  }

  Future<RecordedAudio?> _stopWebAudio(DateTime? started) async {
    try {
      _processor?.disconnect();
    } catch (_) {}
    try {
      _sourceNode?.disconnect();
    } catch (_) {}
    try {
      await _audioContext?.close();
    } catch (_) {}

    _stream?.getTracks().forEach((t) => t.stop());

    _processor = null;
    _sourceNode = null;
    _audioContext = null;
    _stream = null;

    if (_pcmChunks.isEmpty) return null;
    final bytes = _encodeWav(_pcmChunks, _sampleRate, 1);
    _pcmChunks.clear();

    final duration = started == null
        ? Duration(milliseconds: (bytes.length / 2 / _sampleRate * 1000).round())
        : DateTime.now().difference(started);

    return RecordedAudio(
      fileName: _fileNameForMime('audio/wav'),
      mime: 'audio/wav',
      duration: duration,
      bytes: bytes,
    );
  }

  Future<Uint8List?> _blobToBytes(html.Blob blob) async {
    final completer = Completer<Uint8List?>();
    final reader = html.FileReader();
    reader.onLoad.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
      } else {
        completer.complete(null);
      }
    });
    reader.onError.listen((_) => completer.complete(null));
    reader.readAsArrayBuffer(blob);
    return completer.future;
  }

  Uint8List _encodeWav(List<Float32List> buffers, int sampleRate, int channels) {
    var totalSamples = 0;
    for (final buf in buffers) {
      totalSamples += buf.length;
    }

    final byteLength = 44 + totalSamples * 2;
    final data = ByteData(byteLength);
    int offset = 0;

    void writeString(String value) {
      for (int i = 0; i < value.length; i++) {
        data.setUint8(offset++, value.codeUnitAt(i));
      }
    }

    void writeUint32(int value) {
      data.setUint32(offset, value, Endian.little);
      offset += 4;
    }

    void writeUint16(int value) {
      data.setUint16(offset, value, Endian.little);
      offset += 2;
    }

    writeString('RIFF');
    writeUint32(36 + totalSamples * 2);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1);
    writeUint16(channels);
    writeUint32(sampleRate);
    writeUint32(sampleRate * channels * 2);
    writeUint16(channels * 2);
    writeUint16(16);
    writeString('data');
    writeUint32(totalSamples * 2);

    for (final buf in buffers) {
      for (int i = 0; i < buf.length; i++) {
        var sample = (buf[i] * 32767).round();
        if (sample > 32767) sample = 32767;
        if (sample < -32768) sample = -32768;
        data.setInt16(offset, sample, Endian.little);
        offset += 2;
      }
    }

    return data.buffer.asUint8List();
  }

  String _fileNameForMime(String mime) {
    final now = DateTime.now().toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll('.', '');
    final ext = _extForMime(mime);
    return 'audio_$now$ext';
  }

  String _extForMime(String mime) {
    final lower = mime.toLowerCase();
    if (lower.contains('wav')) return '.wav';
    if (lower.contains('ogg')) return '.ogg';
    if (lower.contains('webm')) return '.webm';
    return '.webm';
  }
}
