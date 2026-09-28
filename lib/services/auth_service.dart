import 'package:firebase_core/firebase_core.dart';

/// Firebase bootstrap. Stays disabled until a real Firebase project is
/// configured (google-services.json + FirebaseOptions). The app runs fully
/// offline without it — initializeApp is wrapped in try/catch.
class AuthService {
  static bool cloudEnabled = false;
  static bool _initDone = false;

  static Future<void> init() async {
    if (_initDone) return;
    _initDone = true;
    try {
      await Firebase.initializeApp();
      // If we reach here, native config exists.
      cloudEnabled = true;
    } catch (_) {
      cloudEnabled = false;
    }
  }
}
