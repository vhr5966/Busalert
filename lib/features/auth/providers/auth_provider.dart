/// Riverpod state management for authentication using Firebase Auth.
///
/// This provider manages the entire auth lifecycle: login, register, logout,
/// session restoration, and auth state streaming to the rest of the app.
///
/// Firebase Auth handles:
/// - Secure credential storage (no manual JWT management needed)
/// - Session persistence across app restarts (auto-restored)
/// - Email/password authentication
library;

import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, FirebaseAuthException, UserCredential;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_handler.dart';
import '../../../data/models/user.dart';

/// Represents the possible states of the authentication flow.
sealed class AuthState {
  const AuthState();
}

/// Initial state — we haven't checked for a stored session yet.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading while checking stored token or performing login/register.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// User is authenticated.
class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
}

/// User is not authenticated (no stored token / logged out).
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An error occurred during authentication.
class AuthError extends AuthState {
  final AppError error;
  const AuthError(this.error);
}

/// Notifier that encapsulates authentication business logic via Firebase Auth.
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthNotifier() : super(const AuthInitial()) {
    // Listen for Firebase Auth state changes (auto-restores session).
    // This simplifies session management — Firebase automatically persists
    // the authentication state and restores it on app restart.
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Handles Firebase Auth state changes.
  ///
  /// Called automatically when:
  /// - The app starts (restores previous session)
  /// - The user signs in or out
  /// - The token refreshes
  void _onAuthStateChanged(firebase_auth.User? firebaseUser) {
    if (firebaseUser != null) {
      final user = User(
        id: int.tryParse(firebaseUser.uid.hashCode.toString()) ?? 0,
        name: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? '',
        token: '', // Firebase Auth manages tokens internally
      );
      state = AuthAuthenticated(user);
    } else if (state is! AuthInitial && state is! AuthLoading) {
      state = const AuthUnauthenticated();
    }
  }

  /// Attempts to restore a previous session.
  ///
  /// Firebase Auth automatically persists the session, so we just check
  /// if there's a currently signed-in user.
  Future<void> tryAutoLogin() async {
    state = const AuthLoading();
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      final user = User(
        id: int.tryParse(firebaseUser.uid.hashCode.toString()) ?? 0,
        name: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? '',
        token: '',
      );
      state = AuthAuthenticated(user);
    } else {
      state = const AuthUnauthenticated();
    }
  }

  /// Registers a new user account via Firebase Auth.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update the user's display name in Firebase
      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();

      final firebaseUser = _auth.currentUser;
      final user = User(
        id: int.tryParse(firebaseUser?.uid.hashCode.toString() ?? '0') ?? 0,
        name: name.trim(),
        email: email.trim(),
        token: '',
      );
      state = AuthAuthenticated(user);
    } on FirebaseAuthException catch (e) {
      state = AuthError(_parseFirebaseError(e));
    } catch (e) {
      state = AuthError(parseError(e));
    }
  }

  /// Logs in with existing credentials via Firebase Auth.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Auth state change is handled by _onAuthStateChanged
    } on FirebaseAuthException catch (e) {
      state = AuthError(_parseFirebaseError(e));
    } catch (e) {
      state = AuthError(parseError(e));
    }
  }

  /// Logs out and clears the Firebase session.
  Future<void> logout() async {
    await _auth.signOut();
    state = const AuthUnauthenticated();
  }

  /// Clears any error state.
  void clearError() {
    if (state is AuthError) {
      state = const AuthUnauthenticated();
    }
  }

  /// Maps Firebase Auth exceptions to user-friendly error messages.
  AppError _parseFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return const AppError(
          userMessage: 'Invalid email or password.',
        );
      case 'email-already-in-use':
        return const AppError(
          userMessage: 'An account with this email already exists.',
        );
      case 'weak-password':
        return const AppError(
          userMessage: 'Password is too weak. Use at least 6 characters.',
        );
      case 'invalid-email':
        return const AppError(
          userMessage: 'Please enter a valid email address.',
        );
      case 'too-many-requests':
        return const AppError(
          userMessage: 'Too many attempts. Please try again later.',
        );
      case 'network-request-failed':
        return const AppError(
          userMessage: 'Network error. Please check your connection.',
        );
      default:
        return AppError(
          userMessage: 'Authentication failed. Please try again.',
          technicalDetail: e.code,
        );
    }
  }
}

/// The global auth provider.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
