/// Web stub — never called (hive_service uses Hive.initFlutter on web,
/// exports/backups use browser downloads). Importing this keeps the
/// conditional export in app_paths.dart compiling for Flutter web.
class AppPaths {
  static const String packageName = 'com.hisab.finance';

  static Future<Never> documentsDir() =>
      throw UnsupportedError('No documents dir on web');

  static Future<Never> externalFilesDir() =>
      throw UnsupportedError('No external files dir on web');

  static Future<Never> externalOrDocuments(String subdir) =>
      throw UnsupportedError('No app dirs on web');
}
