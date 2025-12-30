import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> saveBytes(String fileName, List<int> bytes) async {
  final dir =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, fileName);
  final f = File(path);
  await f.writeAsBytes(bytes, flush: true);
  return path;
}

Future<String?> downloadBytesWeb(String name, List<int> bytes,
        {String mimeType = 'application/octet-stream'}) async =>
    null;
Future<String?> downloadTextWeb(String name, String text,
        {String mimeType = 'text/plain'}) async =>
    null;
Future<String?> pickTextFileWeb() async => null;
