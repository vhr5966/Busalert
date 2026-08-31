/// Main entry point for BusAlert Cardiff.
///
/// Sets up:
/// - Firebase initialization (optional - works without config)
/// - Riverpod for state management
/// - Material 3 theming with Cardiff blue
/// - Named routing for all screens
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'firebase_options.dart';
import 'screens/home_dashboard.dart';
import 'screens/splash_screen.dart';

/// Global flag to track if Firebase is available
bool firebaseAvailable = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to initialize Firebase — if it fails, the app still works
  // without cloud features (journey history won't sync to cloud)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable Firestore offline persistence so the app works without
    // a network connection. Writes are queued locally and synced when
    // connectivity returns.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );

    firebaseAvailable = true;
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    firebaseAvailable = false;
    debugPrint('⚠️ Firebase initialization failed: $e');
    debugPrint('   App will run without cloud features');
  }

  runApp(
    const ProviderScope(
      child: BusAlertApp(),
    ),
  );
}

/// Root widget for BusAlert Cardiff.
///
/// Configures theming and routing.
class BusAlertApp extends ConsumerStatefulWidget {
  const BusAlertApp({super.key});

  @override
  ConsumerState<BusAlertApp> createState() => _BusAlertAppState();
}

class _BusAlertAppState extends ConsumerState<BusAlertApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BusAlert Cardiff',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeDashboard(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
