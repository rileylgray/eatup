import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// TODO(release): replace this file by running `flutterfire configure` for
/// the EatUp Firebase project (Analytics + Remote Config). Until then Firebase
/// is skipped at startup: analytics are no-ops and every remote-config knob
/// uses its shipped default, so the game works exactly the same.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('Firebase is not configured yet: run `flutterfire configure`.');
}
