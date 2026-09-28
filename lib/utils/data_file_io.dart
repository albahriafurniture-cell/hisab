import 'dart:io';

import 'app_paths_io.dart';
import 'data_file.dart';

Future<String> saveDataFile(
    String subdir, String fileName, List<int> bytes) async {
  final dir = await AppPaths.externalOrDocuments(subdir);
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return 'Saved: $fileName\n${dir.path}';
}

Future<String> saveTextFile(
    String subdir, String fileName, String text) async {
  final dir = await AppPaths.externalOrDocuments(subdir);
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(text, flush: true);
  return 'Saved: $fileName\n${dir.path}';
}

Future<List<StoredBackup>> listStoredBackups(
    String subdir, String prefix) async {
  final dir = await AppPaths.externalOrDocuments(subdir);
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) =>
          f.path.split('/').last.startsWith(prefix) &&
          f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  return [
    for (final f in files)
      StoredBackup(
        name: f.path.split('/').last,
        label: f.path
            .split('/')
            .last
            .replaceFirst(prefix, '')
            .replaceFirst('.json', '')
            .replaceAll('-', ' '),
        sizeLabel: '${(f.lengthSync() / 1024).toStringAsFixed(1)} KB',
      ),
  ];
}

Future<String> readStoredBackup(String subdir, StoredBackup backup) async {
  final dir = await AppPaths.externalOrDocuments(subdir);
  return File('${dir.path}/${backup.name}').readAsString();
}

Future<String?> pickTextFile() async => null;
