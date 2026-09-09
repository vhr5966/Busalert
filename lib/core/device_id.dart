/// Service for generating and persisting a unique device ID.
///
/// This provides a stable, anonymous user identifier without requiring
/// Firebase Auth. The ID is persisted locally using SharedPreferences.
library;

import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdService {
  static const String _key = 'bus_alert_device_id';
  static String? _cachedId;

  /// Returns a stable, unique ID for this device.
  ///
  /// On first call, generates a new UUID and persists it.
  /// Subsequent calls return the cached/persisted ID.
  static Future<int> getDeviceUserId() async {
    if (_cachedId != null) {
      return _cachedId.hashCode;
    }

    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_key);

    if (deviceId == null || deviceId.isEmpty) {
      // Generate a new unique ID
      deviceId = _generateId();
      await prefs.setString(_key, deviceId);
    }

    _cachedId = deviceId;
    return _cachedId.hashCode;
  }

  /// Generates a simple unique ID.
  static String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = now.hashCode;
    return 'device_${now}_$random';
  }

  /// Clears the cached ID (for testing purposes).
  static void clearCache() {
    _cachedId = null;
  }
}
