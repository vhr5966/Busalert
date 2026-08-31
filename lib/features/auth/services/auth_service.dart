/// Service for authenticating users with the Node.js backend.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_config.dart';
import '../../../data/models/user.dart';

class AuthService {
  static const String _userKey = 'cached_auth_user';
  static const String _guestKey = 'is_guest_mode';

  /// Registers a new user account with the backend.
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/auth/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = User.fromJson(data);
      await saveUser(user);
      await setGuestMode(false);
      return user;
    } else {
      final errorBody = jsonDecode(response.body);
      final message = errorBody['error'] ?? 'Registration failed.';
      throw Exception(message);
    }
  }

  /// Logs in an existing user with email and password.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = User.fromJson(data);
      await saveUser(user);
      await setGuestMode(false);
      return user;
    } else {
      final errorBody = jsonDecode(response.body);
      final message = errorBody['error'] ?? 'Invalid email or password.';
      throw Exception(message);
    }
  }

  /// Saves the authenticated user locally.
  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  /// Loads the persisted user session from local storage.
  Future<User?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    try {
      final map = jsonDecode(userJson) as Map<String, dynamic>;
      return User.fromJson(map);
    } catch (e) {
      debugPrint('⚠️ Failed to restore saved user session: $e');
      return null;
    }
  }

  /// Sets whether the app is running in Guest mode.
  Future<void> setGuestMode(bool isGuest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, isGuest);
  }

  /// Checks if the app was launched in Guest mode.
  Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestKey) ?? false;
  }

  /// Logs out the user and clears stored credentials.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_guestKey);
  }
}
