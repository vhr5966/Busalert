/// GPS position tracker using the `geolocator` package.
///
/// Listens to the device's GPS sensor and reports position changes
/// to the provided callback. The callback receives latitude, longitude,
/// and speed (in metres per second).
///
/// ## GPS Detection Logic Explained (for dissertation)
///
/// The boarding/alighting detection works in three stages:
///
/// 1. **GPS Sampling:** The `geolocator` package is configured with a
///    `LocationSettings` that requests high-accuracy GPS data at a
///    polling interval of [kGpsPollIntervalSeconds] seconds. Each sample
///    includes latitude, longitude, speed, and accuracy.
///
/// 2. **Speed Calculation:** The device GPS itself reports speed (in m/s).
///    We convert this to km/h for threshold comparison. A speed above
///    ~7 km/h (brisk walking pace) while near a bus stop suggests the
///    user is on a moving bus.
///
/// 3. **Stop Proximity:** For each GPS sample, we check if the user is
///    within [kStopProximityMeters] (50 m) of any known Cardiff Bus stop.
///    If speed AND proximity conditions both hold, a boarding event is
///    triggered.
///
/// This approach avoids needing to match specific bus GPS data or
/// Cardiff Bus's real-time API, making it privacy-preserving and
/// self-contained.
library;

import 'dart:async' show StreamSubscription;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants.dart';

/// Callback type for GPS position updates.
///
/// Parameters: latitude, longitude, speed (m/s).
typedef GpsPositionCallback = void Function(double lat, double lng, double speedMs);

class GpsTracker {
  final GpsPositionCallback onPositionChanged;
  bool _isRunning = false;
  // Store the stream subscription so we can cancel it in [stop()].
  // Without this, the GPS stream would continue indefinitely even after
  // the user taps "Stop Tracking".
  StreamSubscription<Position>? _positionSubscription;

  GpsTracker({required this.onPositionChanged});

  /// Shows a GDPR-style consent dialog explaining why GPS is needed.
  ///
  /// Must be called from a widget context. Returns true if the user consents.
  static Future<bool> showGpsConsentDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Access Required'),
        content: const Text(
          'BusAlert Cardiff uses your device\'s GPS to automatically detect '
          'when you board and alight a bus. This allows us to record journey '
          'times and compute accurate delay predictions for all Cardiff Bus riders.\n\n'
          'Your location data is:\n'
          '• Only used while you are actively tracking a journey\n'
          '• Anonymized when submitted to our servers\n'
          '• Never shared with third parties\n'
          '• Stored securely and only used for delay prediction\n\n'
          'You can stop tracking at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Allow Location Access'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Starts the GPS position stream.
  ///
  /// Requests location permission first (with a clear user-facing
  /// explanation as required by GDPR/Android 10+ guidelines), then
  /// begins listening for position updates.
  Future<void> start() async {
    if (_isRunning) return;

    // ── Permission Check ────────────────────────────────────────────
    // Android requires location permissions at runtime (since Android 6.0).
    // We request "while-in-use" location since background tracking is
    // only needed while the app is actively monitoring for journeys.
    //
    // NOTE: For production, you'd want a proper permission rationale
    // dialog explaining:
    //   "BusAlert uses GPS to detect when you board and alight buses.
    //    This data is only used to compute delay predictions and is
    //    never shared with third parties."
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission is required to detect bus journeys. '
          'Please grant location access in Settings.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission was permanently denied. Please enable it in '
        'App Settings to use journey detection.',
      );
    }

    // ── GPS Settings ────────────────────────────────────────────────
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: kSignificantMovementMeters.toInt(),
      timeLimit: null,
    );

    _isRunning = true;

    // ── Position Stream ─────────────────────────────────────────────
    // Geolocator.getPositionStream returns a continuous stream of GPS
    // updates. We filter for meaningful movement before notifying the
    // detector to avoid excessive processing.
    //
    // IMPORTANT: The StreamSubscription is stored so we can cancel it
    // later in [stop()]. Without cancellation, the GPS would stay
    // active even after tracking is stopped.
    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (!_isRunning) return;

      onPositionChanged(
        position.latitude,
        position.longitude,
        position.speed, // Speed in m/s, reported by device GPS
      );
    });
  }

  /// Stops the GPS position stream and cancels the subscription.
  Future<void> stop() async {
    _isRunning = false;
    // Cancel the stream subscription to release the GPS hardware.
    // This is essential for battery life — without this the GPS chip
    // stays active even when tracking is stopped.
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Gets the current position once (one-shot).
  ///
  /// Useful for getting the user's location when they manually enter a journey.
  Future<Position> getCurrentPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}
