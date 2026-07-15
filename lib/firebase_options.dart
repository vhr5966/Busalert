// ============================================================================
// Firebase Configuration
// Generated from Firebase project: busalert-c9d22 (862434879787)
//
// Android: fully configured
// iOS / Web / Desktop: project-level values filled; app ID needs updating
//   after adding those platforms in the Firebase Console:
//   https://console.firebase.google.com/project/busalert-c9d22/settings/general
// ============================================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Default [FirebaseOptions] for the current platform.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (Platform.isIOS) return ios;
    if (Platform.isMacOS) return macos;
    if (Platform.isLinux) return linux;
    if (Platform.isWindows) return windows;
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-uGyj9wBHhJjryk7yoGNMky1sHaUKkVk',
    appId: '1:862434879787:android:97f08abb1e81d1aa8ffd6e',
    messagingSenderId: '862434879787',
    projectId: 'busalert-c9d22',
    storageBucket: 'busalert-c9d22.firebasestorage.app',
  );

  // ------------------------------------------------------------------
  // iOS
  // To enable iOS, add an iOS app in the Firebase Console at:
  //   https://console.firebase.google.com/project/busalert-c9d22/settings/general
  // Then replace the appId and iosClientId below.
  // ------------------------------------------------------------------
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA-uGyj9wBHhJjryk7yoGNMky1sHaUKkVk',
    appId: '1:862434879787:ios:REPLACE_ME',
    messagingSenderId: '862434879787',
    projectId: 'busalert-c9d22',
    storageBucket: 'busalert-c9d22.firebasestorage.app',
    iosClientId:
        'REPLACE_ME.apps.googleusercontent.com',
    iosBundleId: 'com.example.busalert',
  );

  // ------------------------------------------------------------------
  // Web
  // To enable Web, add a Web app in the Firebase Console at:
  //   https://console.firebase.google.com/project/busalert-c9d22/settings/general
  // Then replace the appId and authDomain below.
  // ------------------------------------------------------------------
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA-uGyj9wBHhJjryk7yoGNMky1sHaUKkVk',
    appId: '1:862434879787:web:REPLACE_ME',
    messagingSenderId: '862434879787',
    projectId: 'busalert-c9d22',
    authDomain: 'busalert-c9d22.firebaseapp.com',
    storageBucket: 'busalert-c9d22.firebasestorage.app',
    measurementId: '',
  );

  // ------------------------------------------------------------------
  // macOS
  // Same app as iOS – register a macOS app in the Firebase Console.
  // ------------------------------------------------------------------
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA-uGyj9wBHhJjryk7yoGNMky1sHaUKkVk',
    appId: '1:862434879787:ios:REPLACE_ME',
    messagingSenderId: '862434879787',
    projectId: 'busalert-c9d22',
    storageBucket: 'busalert-c9d22.firebasestorage.app',
    iosClientId:
        'REPLACE_ME.apps.googleusercontent.com',
    iosBundleId: 'com.example.busalert',
  );

  // ------------------------------------------------------------------
  // Linux & Windows
  // Desktop apps share the Web API key. Register them in the Firebase
  // Console and update the appId below.
  // ------------------------------------------------------------------
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyA-uGyj9wBHhJjryk7yoGNMky1sHaUKkVk',
    appId: '1:862434879787:web:REPLACE_ME',
    messagingSenderId: '862434879787',
    projectId: 'busalert-c9d22',
    authDomain: 'busalert-c9d22.firebaseapp.com',
    storageBucket: 'busalert-c9d22.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA-uGyj9wBHhJjryk7yoGNMky1sHaUKkVk',
    appId: '1:862434879787:web:REPLACE_ME',
    messagingSenderId: '862434879787',
    projectId: 'busalert-c9d22',
    authDomain: 'busalert-c9d22.firebaseapp.com',
    storageBucket: 'busalert-c9d22.firebasestorage.app',
  );
}
