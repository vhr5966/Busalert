/// Service for authenticating users with the Node.js backend.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_config.dart';
import '../../../core/logger/app_logger.dart';
import '../../../data/models/user.dart';

class AuthService {
  static const String _userKey = 'cached_auth_user';
  static const String _guestKey = 'is_guest_mode';

  /// Timeout duration allowing Render free-tier instances to wake from sleep.
  static const Duration _requestTimeout = Duration(seconds: 60);

  /// Registers a new user account with the backend.
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/auth/register');
    
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name.trim(),
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      AppLogger.warn('Registration request timed out waiting for server wake-up');
      throw Exception('Server took too long to wake up. Please wait a few seconds and try again.');
    } on SocketException catch (e) {
      AppLogger.warn('Registration socket exception: $e');
      throw Exception('Unable to reach server. Please check your internet connection.');
    } on http.ClientException catch (e) {
      AppLogger.warn('Registration client exception: $e');
      throw Exception('Connection interrupted while server was waking up. Please try again.');
    } catch (e, stack) {
      AppLogger.error('Unexpected error during registration: $e', e, stack);
      throw Exception('Connection error. Please try again.');
    }

    if (response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = User.fromJson(data);
        await saveUser(user);
        await setGuestMode(false);
        return user;
      } catch (e, stack) {
        AppLogger.error('Failed to parse registration response JSON', e, stack);
        throw Exception('Received unexpected response format from server.');
      }
    } else if (response.statusCode == 429) {
      AppLogger.warn('Received 429 Too Many Requests from server');
      throw Exception('Too many requests. The server is warming up, please wait a moment and try again.');
    } else if (response.statusCode == 409) {
      throw Exception('An account with this email already exists. Please sign in instead.');
    } else if (response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504) {
      AppLogger.warn('Server gateway error ${response.statusCode} (likely waking up)');
      throw Exception('Server is waking up from sleep mode. Please wait 15 seconds and try again.');
    } else {
      String? errorMessage;
      try {
        final dynamic errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('error')) {
          errorMessage = errorBody['error']?.toString();
        }
      } catch (_) {
        // Response body is not JSON (e.g. HTML error page from proxy)
      }
      throw Exception(errorMessage ?? 'Registration failed (${response.statusCode}). Please try again.');
    }
  }

  /// Logs in an existing user with email and password.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/auth/login');

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      AppLogger.warn('Login request timed out waiting for server wake-up');
      throw Exception('Server took too long to wake up. Please wait a few seconds and try again.');
    } on SocketException catch (e) {
      AppLogger.warn('Login socket exception: $e');
      throw Exception('Unable to reach server. Please check your internet connection.');
    } on http.ClientException catch (e) {
      AppLogger.warn('Login client exception: $e');
      throw Exception('Connection interrupted while server was waking up. Please try again.');
    } catch (e, stack) {
      AppLogger.error('Unexpected error during login: $e', e, stack);
      throw Exception('Connection error. Please try again.');
    }

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = User.fromJson(data);
        await saveUser(user);
        await setGuestMode(false);
        return user;
      } catch (e, stack) {
        AppLogger.error('Failed to parse login response JSON', e, stack);
        throw Exception('Received unexpected response format from server.');
      }
    } else if (response.statusCode == 429) {
      AppLogger.warn('Received 429 Too Many Requests on login');
      throw Exception('Too many requests. The server is warming up, please wait a moment and try again.');
    } else if (response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504) {
      AppLogger.warn('Server gateway error ${response.statusCode} on login');
      throw Exception('Server is waking up from sleep mode. Please wait 15 seconds and try again.');
    } else {
      String? errorMessage;
      try {
        final dynamic errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('error')) {
          errorMessage = errorBody['error']?.toString();
        }
      } catch (_) {
        // Body is not JSON
      }
      throw Exception(errorMessage ?? 'Invalid email or password.');
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
      AppLogger.warn('Failed to restore saved user session: $e');
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
