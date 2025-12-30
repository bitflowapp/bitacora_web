import 'dart:typed_data';
import 'dart:html' as html;

Future<String> saveBytes(String fileName, List<int> bytes) async {
  final blob =
      html.Blob([Uint8List.fromList(bytes)], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)..download = fileName;
  a.click();
  html.Url.revokeObjectUrl(url);
  return fileName;
}

Future<String?> downloadBytesWeb(String name, List<int> bytes,
    {String mimeType = 'application/octet-stream'}) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)..download = name;
  a.click();
  html.Url.revokeObjectUrl(url);
  return name;
}

Future<String?> downloadTextWeb(String name, String text,
    {String mimeType = 'text/plain'}) async {
  final blob = html.Blob([text], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)..download = name;
  a.click();
  html.Url.revokeObjectUrl(url);
  return name;
}

Future<String?> pickTextFileWeb() async {
  final input = html.FileUploadInputElement()
    ..accept = '.json,text/json,application/json';
  input.click();
  await input.onChange.first;
  final file = input.files?.first;
  if (file == null) return null;
  final reader = html.FileReader()..readAsText(file);
  await reader.onLoad.first;
  return reader.result as String?;
}
