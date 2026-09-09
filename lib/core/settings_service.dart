/// Service for persisting user preferences via SharedPreferences.
///
/// Centralises the storage keys and defaults so screens and providers
/// can read/write settings consistently without touching the raw
/// SharedPreferences API.
library;

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  /// Key for the WiFi bus-line detection toggle.
  static const String _kWifiDetectionKey = 'settings_wifi_detection';

  /// Whether auto-detection of the bus line via Cardiff Bus onboard WiFi
  /// is enabled during journey tracking.
  ///
  /// Defaults to `true` so the feature is on for existing users.
  Future<bool> isWifiDetectionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kWifiDetectionKey) ?? true;
  }

  /// Persists the WiFi bus-line detection preference.
  Future<void> setWifiDetectionEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWifiDetectionKey, enabled);
  }
}
