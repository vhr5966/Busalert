/// Centralized API configuration for BusAlert backend endpoints.
library;

import 'package:flutter/foundation.dart';

class ApiConfig {
  /// 🌐 Paste your deployed Render backend link here:
  /// (e.g. 'https://busalert-backend.onrender.com')
  /// When this is set, the app will automatically connect to your live Render backend!
  static const String customRenderUrl = '';

  /// Base backend URL configured via:
  /// 1. [customRenderUrl] (if pasted above)
  /// 2. --dart-define=BACKEND_URL=... (if passed during flutter run / build)
  /// 3. Default local fallback (10.0.2.2 for Android emulator, localhost for web/desktop).
  static String get backendBaseUrl {
    if (customRenderUrl.trim().isNotEmpty) {
      final url = customRenderUrl.trim();
      return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    }

    const defined = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    if (defined.isNotEmpty) return defined;

    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
}
