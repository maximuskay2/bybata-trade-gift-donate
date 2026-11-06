// GENERATED MANUALLY FOR WEB ONLY.
// For iOS/Android, Firebase uses GoogleService-Info.plist / google-services.json.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'DefaultFirebaseOptions are not configured for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
    authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    messagingSenderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    appId: const String.fromEnvironment('FIREBASE_APP_ID'),
    measurementId: const String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
  );
}
