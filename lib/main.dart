/// Main entry point for BusAlert Cardiff (Firebase edition).
///
/// Sets up:
/// - Firebase initialization (Auth, Firestore, Functions)
/// - Riverpod for state management
/// - Material 3 theming with Cardiff blue
/// - Named routing for all screens
///
/// ## Architecture Overview (for dissertation)
///
/// This app follows a **clean architecture** pattern with Firebase:
///
/// - **Presentation layer** (`screens/`, `widgets/`, `features/*/screens/`):
///   Flutter widgets that render the UI. Each screen is a ConsumerStatefulWidget
///   that watches Riverpod providers for state.
///
/// - **State management layer** (`features/*/providers/`):
///   Riverpod StateNotifiers that hold business logic and orchestrate
///   between UI and Firebase services.
///
/// - **Data layer** (`data/models/`, `data/repositories/`, `data/services/`):
///   Models, repositories, and Firebase service classes that handle data
///   persistence via Cloud Firestore and authentication via Firebase Auth.
///
/// - **Core layer** (`core/`):
///   Shared constants, theme configuration, utility functions, and
///   error handling used across the entire app.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/map/screens/map_screen.dart';
import 'features/prediction/screens/prediction_screen.dart';
import 'features/tracking/screens/live_tracking_screen.dart';
import 'firebase_options.dart';
import 'screens/home_dashboard.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase — this must complete before any Firebase service
  // (Auth, Firestore, Functions) can be used.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence so the app works without
  // a network connection. Writes are queued locally and synced when
  // connectivity returns.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

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
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeDashboard(),
        '/predict': (context) => const PredictionScreen(),
        '/track': (context) => const LiveTrackingScreen(),
        '/history': (context) => const HistoryScreen(),
        '/map': (context) => const MapScreen(),
      },
    );
  }
}
