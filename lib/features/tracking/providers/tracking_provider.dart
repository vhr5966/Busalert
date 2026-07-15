/// Riverpod state management for journey tracking (boarding/alighting).
///
/// This provider orchestrates the GPS tracking lifecycle: starting/stopping
/// the GPS listener, detecting boarding and alighting events, and recording
/// completed journeys. Uses Firebase Auth to identify the current user.
library;

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/bus_stop.dart';
import '../../../data/models/journey.dart';
import '../../../data/repositories/journey_repository.dart';
import '../../../data/services/stop_service.dart';
import '../services/boarding_detector.dart';
import '../services/gps_tracker.dart';

/// Singleton instances
final FirebaseAuth _auth = FirebaseAuth.instance;
final JourneyRepository _journeyRepository = JourneyRepository();
final StopService _stopService = StopService();

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
  Future<void> init() async {
    _stops = await _stopService.getStops();
  }

  /// Starts GPS tracking and boarding detection.
  Future<void> startTracking() async {
    state = const TrackingIdle();

    _gpsTracker = GpsTracker(
      onPositionChanged: _onPositionChanged,
    );
    _detector = BoardingDetector(stops: _stops);

    await _gpsTracker!.start();
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
        // Try to detect bus line via WiFi before emitting the boarding state.
        // This is async so we kick it off and update state when done.
        _detector?.detectBusLineViaWiFi().then((wifiLine) {
          final line = wifiLine.isNotEmpty ? wifiLine : boardingResult.detectedBusLine;
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

  /// Records a completed journey and submits to Firestore.
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
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      state = const TrackingError('User not authenticated');
      return;
    }

    final journey = Journey(
      userId: firebaseUser.uid.hashCode,
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
    await _journeyRepository.submitJourney(journey);
    state = const TrackingIdle();
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
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      state = const TrackingError('User not authenticated');
      return;
    }

    final journey = Journey(
      userId: firebaseUser.uid.hashCode,
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
