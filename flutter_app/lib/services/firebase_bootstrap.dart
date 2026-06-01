import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Initializes Firebase without throwing, so the app can still run when the
/// platform config is missing or initialization fails.
///
/// Uses the generated [DefaultFirebaseOptions.currentPlatform] (from
/// `flutterfire configure`) so init works consistently across iOS/macOS.
/// Returns true when Firebase initialized successfully, false otherwise.
Future<bool> initFirebaseSafely() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } catch (e) {
    debugPrint('Firebase initialization skipped/failed: $e');
    return false;
  }
}
