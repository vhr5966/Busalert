/// Splash screen shown on app startup.
///
/// While the splash displays the app branding, it attempts to restore the
/// user's previous Firebase Auth session. If a valid session exists,
/// the user goes to the home dashboard; otherwise they see the login screen.
///
/// This provides a seamless experience — returning users don't need to
/// log in every time.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../features/auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Defer auth check to the next microtask so Riverpod state changes
    // don't happen during the widget tree building phase (which would
    // throw an assertion error). This is a common pattern when calling
    // state-modifying async functions from initState.
    Future.microtask(_checkAuth);
  }

  Future<void> _checkAuth() async {
    try {
      await ref.read(authProvider.notifier).tryAutoLogin();
    } catch (_) {
      // Auth check failed — e.g. FlutterSecureStorage platform channel not
      // available (this happens in test environments). State remains
      // AuthInitial, and the navigation below correctly routes to /login.
    }

    // Navigate based on auth state after a short delay for branding display
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState is AuthAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_bus_rounded,
              size: 96,
              color: kCardiffBlue,
            ),
            const SizedBox(height: 24),
            Text(
              'BusAlert Cardiff',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: kCardiffBlue,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crowdsourced delay predictions',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: kCardiffBlue),
          ],
        ),
      ),
    );
  }
}
