// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

import 'data_file.dart';

void _download(String fileName, String mime, List<int> bytes) {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = fileName
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<String> saveDataFile(
    String subdir, String fileName, List<int> bytes) async {
  _download(fileName, 'application/octet-stream', bytes);
  return 'Downloaded: $fileName';
}

Future<String> saveTextFile(
    String subdir, String fileName, String text) async {
  _download(fileName, 'text/plain', text.codeUnits);
  return 'Downloaded: $fileName';
}

Future<List<StoredBackup>> listStoredBackups(
        String subdir, String prefix) async =>
    const [];

Future<String> readStoredBackup(String subdir, StoredBackup backup) {
  throw UnsupportedError('No stored backups on web');
}

Future<String?> pickTextFile() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = '.json';
  var picked = false;
  input.onChange.listen((_) {
    picked = true;
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoad.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(reader.result as String?);
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsText(files.first);
  });
  // When the native dialog closes the window regains focus: if nothing was
  // picked by then, the user cancelled.
  html.window.onFocus.first.then((_) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!completer.isCompleted && !picked) completer.complete(null);
    });
  });
  input.click();
  return completer.future;
}
