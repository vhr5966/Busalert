/// Riverpod state management for journey tracking (boarding/alighting).
///
/// This provider orchestrates the GPS tracking lifecycle: starting/stopping
/// the GPS listener, detecting boarding and alighting events, and recording
/// completed journeys. Uses a stable device-based user ID.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device_id.dart';
import '../../../core/settings_service.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/models/journey.dart';
import '../../../data/repositories/journey_repository.dart';
import '../../../data/services/stop_service.dart';
import '../services/boarding_detector.dart';
import '../services/gps_tracker.dart';

/// Singleton instances
final JourneyRepository _journeyRepository = JourneyRepository();
final StopService _stopService = StopService();
final SettingsService _settingsService = SettingsService();

/// Represents the state of the live tracking system.
sealed class TrackingState {
  const TrackingState();
}

/// Tracking is idle (not active).
class TrackingIdle extends TrackingState {
  const TrackingIdle();
}

/// GPS is active and looking for a bus to board.
class TrackingSearching extends TrackingState {
  final double latitude;
  final double longitude;
  const TrackingSearching(this.latitude, this.longitude);
}

/// A bus boarding has been detected, waiting for alighting.
class TrackingOnBus extends TrackingState {
  final BusStop boardStop;
  final String busLine;
  final DateTime boardingTime;
  final double boardLat;
  final double boardLng;

  const TrackingOnBus({
    required this.boardStop,
    required this.busLine,
    required this.boardingTime,
    required this.boardLat,
    required this.boardLng,
  });
}

/// A journey has been completed and is being submitted.
class TrackingJourneyComplete extends TrackingState {
  final Journey journey;
  const TrackingJourneyComplete(this.journey);
}

/// An error occurred during tracking.
class TrackingError extends TrackingState {
  final String message;
  const TrackingError(this.message);
}

/// Notifier that runs the GPS boarding/alighting detection loop.
class TrackingNotifier extends StateNotifier<TrackingState> {
  GpsTracker? _gpsTracker;
  BoardingDetector? _detector;
  List<BusStop> _stops = [];

  TrackingNotifier() : super(const TrackingIdle());

  /// Initialises the tracking system by loading bus stops.
  ///
  /// If the stop data cannot be loaded, tracking is disabled with a
  /// [TrackingError] rather than failing silently.
  Future<void> init() async {
    try {
      _stops = await _stopService.getStops();
    } catch (e) {
      debugPrint('❌ Failed to load bus stops for tracking: $e');
      state = TrackingError(
        'Could not load bus stop data. Please check your connection and try again.',
      );
    }
  }

  /// Starts GPS tracking and boarding detection.
  ///
  /// Any failure (permission denied, GPS disabled, no activity) is
  /// surfaced as a [TrackingError] so the user always sees why tracking
  /// could not start — never an unhandled exception.
  Future<void> startTracking() async {
    state = const TrackingIdle();

    // If stops failed to load earlier, retry once so boarding detection
    // isn't silently disabled. init() sets TrackingError on failure.
    if (_stops.isEmpty) {
      await init();
      if (_stops.isEmpty) return;
    }

    _gpsTracker = GpsTracker(
      onPositionChanged: _onPositionChanged,
    );
    _detector = BoardingDetector(stops: _stops);

    try {
      await _gpsTracker!.start();
    } catch (e) {
      debugPrint('❌ GPS start failed: $e');
      // Stop the tracker so a failed start can't leave the GPS active.
      await _gpsTracker?.stop();
      _gpsTracker = null;
      _detector = null;
      // GpsTracker throws user-friendly messages ("Location permission is
      // required...", "Location services are disabled..."), so surface the
      // message directly without the "Exception: " prefix.
      state = TrackingError(_cleanError(e));
    }
  }

  /// Strips the "Exception: " prefix so the user sees the raw message
  /// that [GpsTracker] throws (those messages are already user-friendly).
  String _cleanError(Object error) {
    final text = error.toString();
    const prefix = 'Exception: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
  }

  /// Resolves the bus line for a boarding event.
  ///
  /// When WiFi detection is enabled, prefers a fresh WiFi scan result and
  /// falls back to the detector's cached line. When it is disabled, always
  /// returns an empty string (and clears any cached WiFi line) so the user
  /// is prompted to confirm the route manually — a stale WiFi-detected line
  /// must never leak through when the feature is turned off.
  Future<String> _resolveBusLine({String? cachedLine}) async {
    if (!await _settingsService.isWifiDetectionEnabled()) {
      _detector?.clearWifiCache();
      debugPrint('⚙️ WiFi bus-line detection disabled — skipping scan');
      return '';
    }

    final wifiLine = await _detector?.detectBusLineViaWiFi() ?? '';
    return wifiLine.isNotEmpty ? wifiLine : (cachedLine ?? '');
  }

  /// Stops GPS tracking and resets the state.
  Future<void> stopTracking() async {
    await _gpsTracker?.stop();
    _gpsTracker = null;
    _detector = null;
    state = const TrackingIdle();
  }

  /// Called by GpsTracker whenever a new GPS position is available.
  void _onPositionChanged(double lat, double lng, double speedMs) {
    final speedKmh = speedMs * 3.6;

    if (state is TrackingSearching || state is TrackingIdle) {
      state = TrackingSearching(lat, lng);

      final boardingResult = _detector?.detectBoarding(
        lat: lat,
        lng: lng,
        speedKmh: speedKmh,
        currentStops: _stops,
      );

      if (boardingResult != null) {
        // Determine the bus line (via WiFi if enabled in settings) before
        // emitting the boarding state. This is async so we kick it off and
        // update state when done.
        _resolveBusLine(cachedLine: boardingResult.detectedBusLine).then((line) {
          state = TrackingOnBus(
            boardStop: boardingResult.stop,
            busLine: line,
            boardingTime: DateTime.now(),
            boardLat: lat,
            boardLng: lng,
          );
        });
      }
    } else if (state is TrackingOnBus) {
      final onBus = state as TrackingOnBus;

      final alightResult = _detector?.detectAlighting(
        lat: lat,
        lng: lng,
        speedKmh: speedKmh,
        currentStops: _stops,
        boardTime: onBus.boardingTime,
      );

      if (alightResult != null) {
        _completeJourney(
          boardStop: onBus.boardStop,
          busLine: onBus.busLine,
          boardingTime: onBus.boardingTime,
          boardLat: onBus.boardLat,
          boardLng: onBus.boardLng,
          alightStop: alightResult.stop,
          alightLat: lat,
          alightLng: lng,
        );
      }
    }
  }

  /// Records a completed journey and submits.
  Future<void> _completeJourney({
    required BusStop boardStop,
    required String busLine,
    required DateTime boardingTime,
    required double boardLat,
    required double boardLng,
    required BusStop alightStop,
    required double alightLat,
    required double alightLng,
  }) async {
    try {
      // Use device-based user ID (works with or without Firebase)
      final userId = await DeviceIdService.getDeviceUserId();

      final journey = Journey(
        userId: userId,
        boardStopId: boardStop.id,
        boardStopName: boardStop.name,
        boardLat: boardLat,
        boardLng: boardLng,
        alightStopId: alightStop.id,
        alightStopName: alightStop.name,
        alightLat: alightLat,
        alightLng: alightLng,
        busLine: busLine,
        boardingTime: boardingTime,
        alightingTime: DateTime.now(),
      );

      state = TrackingJourneyComplete(journey);
      
      // Submit journey (works with or without Firebase)
      await _journeyRepository.submitJourney(journey);
      
      debugPrint('✅ Journey completed and saved');
      state = const TrackingIdle();
    } catch (e) {
      debugPrint('❌ Error completing journey: $e');
      // Don't crash - just log the error and continue
      state = const TrackingIdle();
    }
  }

  /// Manually records a journey (fallback when auto-detection fails).
  Future<void> recordManualJourney({
    required int boardStopId,
    required String boardStopName,
    required double boardLat,
    required double boardLng,
    required String busLine,
    required DateTime boardingTime,
    int? alightStopId,
    String? alightStopName,
    double? alightLat,
    double? alightLng,
    DateTime? alightingTime,
  }) async {
    try {
      // Use device-based user ID (works with or without Firebase)
      final userId = await DeviceIdService.getDeviceUserId();

      final journey = Journey(
        userId: userId,
        boardStopId: boardStopId,
        boardStopName: boardStopName,
        boardLat: boardLat,
        boardLng: boardLng,
        alightStopId: alightStopId,
        alightStopName: alightStopName,
        alightLat: alightLat,
        alightLng: alightLng,
        busLine: busLine,
        boardingTime: boardingTime,
        alightingTime: alightingTime,
      );

      await _journeyRepository.submitJourney(journey);
      debugPrint('✅ Manual journey saved');
    } catch (e) {
      debugPrint('❌ Error saving manual journey: $e');
    }
  }

  @override
  void dispose() {
    _gpsTracker?.stop();
    super.dispose();
  }
}

final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  return TrackingNotifier();
});
