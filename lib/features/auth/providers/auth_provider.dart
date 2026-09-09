/// Riverpod provider managing authentication state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthState {
  final User? user;
  final bool isGuest;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.isGuest = false,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;
  bool get hasAccess => isAuthenticated || isGuest;

  AuthState copyWith({
    User? user,
    bool? isGuest,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isGuest: isGuest ?? this.isGuest,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState(isLoading: true)) {
    init();
  }

  /// Restores session on app startup.
  Future<void> init() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final savedUser = await _authService.getSavedUser();
      if (savedUser != null) {
        state = AuthState(user: savedUser, isGuest: false, isLoading: false);
        return;
      }

      final isGuest = await _authService.isGuestMode();
      state = AuthState(user: null, isGuest: isGuest, isLoading: false);
    } catch (e) {
      state = AuthState(user: null, isGuest: false, isLoading: false, errorMessage: e.toString());
    }
  }

  /// Logs in with email and password.
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.login(email: email, password: password);
      state = AuthState(user: user, isGuest: false, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Registers a new user.
  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      state = AuthState(user: user, isGuest: false, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Continues in guest mode.
  Future<void> continueAsGuest() async {
    await _authService.setGuestMode(true);
    state = const AuthState(user: null, isGuest: true, isLoading: false);
  }

  /// Signs out.
  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(user: null, isGuest: false, isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
