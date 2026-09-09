/// Riverpod state management for user settings.
///
/// Loads persisted preferences from [SettingsService] on startup and
/// exposes setters that persist and update the state immediately.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings_service.dart';

final SettingsService _settingsService = SettingsService();

/// Snapshot of the user's settings.
class SettingsState {
  /// Whether WiFi-based bus-line detection is enabled during tracking.
  final bool wifiDetectionEnabled;

  /// True while initial values are being loaded from storage.
  final bool isLoading;

  const SettingsState({
    this.wifiDetectionEnabled = true,
    this.isLoading = false,
  });

  SettingsState copyWith({
    bool? wifiDetectionEnabled,
    bool? isLoading,
  }) {
    return SettingsState(
      wifiDetectionEnabled: wifiDetectionEnabled ?? this.wifiDetectionEnabled,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState(isLoading: true));

  /// Loads persisted settings from local storage.
  Future<void> load() async {
    final wifiDetectionEnabled =
        await _settingsService.isWifiDetectionEnabled();
    state = SettingsState(
      wifiDetectionEnabled: wifiDetectionEnabled,
      isLoading: false,
    );
  }

  /// Toggles WiFi bus-line detection and persists the choice.
  Future<void> setWifiDetectionEnabled(bool enabled) async {
    await _settingsService.setWifiDetectionEnabled(enabled);
    state = state.copyWith(wifiDetectionEnabled: enabled);
  }
}

/// The global settings provider.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier()..load();
});
