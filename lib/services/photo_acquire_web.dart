import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class WebPhotoPickResult {
  WebPhotoPickResult({
    required this.bytes,
    required this.name,
    required this.mime,
  });

  final Uint8List bytes;
  final String name;
  final String mime;
}

Future<WebPhotoPickResult?> pickImageFromWeb({required bool capture}) async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  if (capture) {
    input.setAttribute('capture', 'environment');
  }

  input.style.display = 'none';
  html.document.body?.append(input);

  final completer = Completer<WebPhotoPickResult?>();
  StreamSubscription<html.Event>? changeSub;
  StreamSubscription<html.Event>? focusSub;

  void finish(WebPhotoPickResult? result) {
    if (completer.isCompleted) return;
    completer.complete(result);
    changeSub?.cancel();
    focusSub?.cancel();
    input.remove();
  }

  changeSub = input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      finish(null);
      return;
    }

    final file = files.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;

    final result = reader.result;
    if (result is! ByteBuffer) {
      finish(null);
      return;
    }

    final bytes = Uint8List.view(result);
    final name = file.name.trim().isNotEmpty ? file.name : 'image.jpg';
    final mime = file.type;
    finish(WebPhotoPickResult(bytes: bytes, name: name, mime: mime));
  });

  // If the user cancels, Safari often fires focus without change.
  focusSub = html.window.onFocus.listen((_) {
    if (completer.isCompleted) return;
    final files = input.files;
    if (files == null || files.isEmpty) {
      finish(null);
    }
  });

  input.click();
  return completer.future;
}
