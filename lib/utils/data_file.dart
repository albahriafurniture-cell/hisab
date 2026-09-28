import 'data_file_io.dart'
    if (dart.library.html) 'data_file_web.dart' as impl;

/// Metadata for a backup file already stored on disk (native platforms).
class StoredBackup {
  final String name;
  final String label;
  final String sizeLabel;
  const StoredBackup(
      {required this.name, required this.label, required this.sizeLabel});
}

/// Save [bytes] as <subdir>/<fileName>.
/// Returns a user-facing confirmation message.
Future<String> saveDataFile(
        String subdir, String fileName, List<int> bytes) =>
    impl.saveDataFile(subdir, fileName, bytes);

/// Save [text] as <subdir>/<fileName>.
/// Returns a user-facing confirmation message.
Future<String> saveTextFile(
        String subdir, String fileName, String text) =>
    impl.saveTextFile(subdir, fileName, text);

/// Native: list stored `<prefix>*.json` files in [subdir], newest first.
/// Web: always empty (backups are downloads there).
Future<List<StoredBackup>> listStoredBackups(
        String subdir, String prefix) =>
    impl.listStoredBackups(subdir, prefix);

/// Native: read a stored backup's full text.
Future<String> readStoredBackup(String subdir, StoredBackup backup) =>
    impl.readStoredBackup(subdir, backup);

/// Web: open a file picker and return the chosen file's text, or null when
/// the user cancels. Native: always null (uses [listStoredBackups]).
Future<String?> pickTextFile() => impl.pickTextFile();
