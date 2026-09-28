import 'dart:io';

/// App directory resolution WITHOUT path_provider.
///
/// Background: path_provider_android 2.x reaches Android through package:jni,
/// which needs the native `libdartjni.so` bundled in the APK. Our manual
/// (Gradle-less) build pipeline cannot compile that NDK library, so any
/// path_provider call crashes the app on startup with a missing-library
/// error. These helpers return exactly the same locations path_provider
/// would (they are deterministic on Android) using plain dart:io.
///
/// - documentsDir() == getApplicationDocumentsDirectory()
///   (Context.getDir("flutter", MODE_PRIVATE))
/// - externalFilesDir() == getExternalFilesDir(null)
///   (no storage permission needed; browsable in the Files app)
class AppPaths {
  static const String packageName = 'com.hisab.finance';

  static Future<Directory> documentsDir() async {
    final dir = Directory('/data/data/$packageName/app_flutter');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory?> externalFilesDir() async {
    final dir =
        Directory('/storage/emulated/0/Android/data/$packageName/files');
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      return null;
    }
  }

  /// Preferred external dir, falling back to the documents dir when
  /// external storage is unavailable (mirrors old path_provider logic).
  static Future<Directory> externalOrDocuments(String subdir) async {
    final base = await externalFilesDir() ?? await documentsDir();
    final dir = Directory('${base.path}/$subdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
