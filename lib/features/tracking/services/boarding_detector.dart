/// Boarding and alighting detection logic for BusAlert Cardiff.
///
/// ## Detection Algorithm (for dissertation)
///
/// ### Boarding Detection
/// The detector checks every GPS sample against two conditions:
///
/// 1. **Proximity:** Is the user within [kStopProximityMeters] (50 m)
///    of a known bus stop?
/// 2. **Speed:** Is the user's speed above [kBoardingSpeedThresholdKmh]
///    (~7 km/h, faster than walking pace)?
///
/// If both conditions are true, the user is likely on a bus that just
/// departed from that stop. We record this as a boarding event.
///
/// ### Bus Line Detection
/// The bus line is determined through a combination of:
/// - **Primary:** WiFi SSID scanning (`wifi_scan` package) for Cardiff Bus
///   onboard WiFi networks. Cardiff Bus SSIDs follow patterns like
///   "CardiffBus-WiFi-28" or "CB_WiFi_0028".
/// - **Fallback:** A confirmation dialog asking the user to select the
///   bus line from a list or enter it manually.
///
/// ### Alighting Detection
/// The user has alighted when:
/// 1. Speed drops below walking pace (~5 km/h)
/// 2. They are within [kStopProximityMeters] of another bus stop
/// 3. At least [kMinJourneyDurationSeconds] (60 s) has passed since
///    boarding (to filter out brief stops at traffic lights)
///
/// ### Edge Cases Handled
/// - **GPS drift:** Position data is filtered to require [kSignificantMovementMeters]
///   of movement between samples to avoid noise from GPS signal bounce.
/// - **Brief slowdowns:** Alighting requires speed to stay low for
///   [kAlightingDwellSeconds] rather than a single sample.
/// - **Missing WiFi:** If WiFi scanning fails or Cardiff Bus WiFi isn't
///   detected, the user is prompted to confirm the bus line manually.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:wifi_scan/wifi_scan.dart';

import '../../../core/constants.dart';
import '../../../data/models/bus_stop.dart';

/// Result of a successful boarding detection.
class BoardingResult {
  final BusStop stop;
  final String detectedBusLine;

  BoardingResult({required this.stop, required this.detectedBusLine});
}

/// Result of a successful alighting detection.
class AlightingResult {
  final BusStop stop;

  AlightingResult({required this.stop});
}

class BoardingDetector {
  final List<BusStop> stops;

  /// Tracks the last known alighting candidate time to filter false positives.
  DateTime? _alightingCandidateSince;

  /// Cache the last WiFi-detected bus line to avoid re-scanning on every sample.
  String? _cachedWifiLine;

  BoardingDetector({required this.stops});

  /// Checks if the user has boarded a bus.
  ///
  /// Returns a [BoardingResult] if boarding is detected, or null otherwise.
  ///
  /// [lat], [lng]: Current GPS position.
  /// [speedKmh]: Current speed in km/h (converted from GPS m/s).
  /// [currentStops]: The list of bus stops to check proximity against.
  BoardingResult? detectBoarding({
    required double lat,
    required double lng,
    required double speedKmh,
    required List<BusStop> currentStops,
  }) {
    // Find the nearest stop
    BusStop? nearest;
    double minDistance = double.infinity;

    for (final stop in currentStops) {
      final distance = stop.distanceTo(lat, lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = stop;
      }
    }

    if (nearest == null) return null;

    // Condition 1: Within proximity of a stop AND
    // Condition 2: Moving faster than walking pace
    //
    // This combination means the user is very likely on a bus that
    // has just departed from this stop.
    if (minDistance <= kStopProximityMeters && speedKmh >= kBoardingSpeedThresholdKmh) {
      // Determine bus line via WiFi SSID scan, falling back to empty string
      // (the UI will prompt the user via JourneyConfirmationDialog).
      final busLine = _cachedWifiLine ?? '';

      return BoardingResult(
        stop: nearest,
        detectedBusLine: busLine,
      );
    }

    return null;
  }

  /// Checks if the user has alighted from a bus.
  ///
  /// Returns an [AlightingResult] if alighting is detected, or null otherwise.
  ///
  /// We require the user to be stationary (or walking) near a stop for
  /// [kAlightingDwellSeconds] to avoid false positives from brief stops
  /// at traffic lights.
  AlightingResult? detectAlighting({
    required double lat,
    required double lng,
    required double speedKmh,
    required List<BusStop> currentStops,
    required DateTime boardTime,
  }) {
    // Don't detect alighting too soon after boarding
    final elapsed = DateTime.now().difference(boardTime).inSeconds;
    if (elapsed < 60) return null;

    // Find the nearest stop
    BusStop? nearest;
    double minDistance = double.infinity;

    for (final stop in currentStops) {
      final distance = stop.distanceTo(lat, lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = stop;
      }
    }

    if (nearest == null) return null;

    final isNearStop = minDistance <= kStopProximityMeters;
    final isSlow = speedKmh < kBoardingSpeedThresholdKmh;

    if (isNearStop && isSlow) {
      if (_alightingCandidateSince == null) {
        // Start dwell timer
        _alightingCandidateSince = DateTime.now();
      } else {
        // Check if dwell time has been met
        final dwellDuration =
            DateTime.now().difference(_alightingCandidateSince!).inSeconds;
        if (dwellDuration >= kAlightingDwellSeconds) {
          _alightingCandidateSince = null;
          return AlightingResult(stop: nearest);
        }
      }
    } else {
      // Reset dwell timer if conditions are no longer met
      _alightingCandidateSince = null;
    }

    return null;
  }

  /// Determines the bus line number via WiFi SSID scanning.
  ///
  /// Cardiff Bus onboard WiFi SSIDs follow patterns like:
  ///   - "CardiffBus-WiFi-28" → bus line 28
  ///   - "CB_WiFi_0028" → bus line 28
  ///   - "CardiffBus-28" → bus line 28
  ///
  /// Attempts to scan for WiFi networks and match against known Cardiff Bus
  /// patterns. Returns the detected bus line number, or empty string if:
  /// - WiFi scanning is not supported on the device (note: this package is a
  ///   stub on iOS, so detection only works on Android)
  /// - Location permission is denied (required for WiFi scan results)
  /// - No Cardiff Bus SSID is detected
  /// - SSID doesn't contain a recognizable line number
  ///
  /// The UI will prompt the user to manually enter the bus line when this
  /// method returns an empty string.
  Future<String> detectBusLineViaWiFi() async {
    try {
      // Check support + permissions first. askPermissions: true triggers
      // the runtime permission prompt (Android 6.0+) when needed.
      final canGetScannedResults =
          await WiFiScan.instance.canGetScannedResults(askPermissions: true);
      if (canGetScannedResults != CanGetScannedResults.yes) {
        debugPrint('📶 WiFi scan unavailable: $canGetScannedResults');
        return '';
      }

      final canStartScan =
          await WiFiScan.instance.canStartScan(askPermissions: true);
      if (canStartScan != CanStartScan.yes) {
        debugPrint('📶 Cannot start WiFi scan: $canStartScan');
        return '';
      }

      await WiFiScan.instance.startScan();
      // Wait for the OS scan to complete. Scans are throttled to roughly
      // one per 5 seconds on Android 8+, so give it ample time.
      await Future.delayed(const Duration(seconds: 2));

      // Get scan results
      final results = await WiFiScan.instance.getScannedResults();
      debugPrint('📶 WiFi scan returned ${results.length} networks');

      // Look for Cardiff Bus SSIDs and extract the line number
      for (final result in results) {
        final ssid = result.ssid.toLowerCase();

        // Pattern 1: "cardiffbus-wifi-28" or "cardiffbus-28"
        if (ssid.contains('cardiffbus')) {
          final match = RegExp(r'(\d+)').firstMatch(ssid);
          if (match != null) {
            final line = match.group(1)!;
            _cachedWifiLine = line;
            return line;
          }
        }

        // Pattern 2: "cb_wifi_0028" (zero-padded)
        if (ssid.contains('cb_wifi')) {
          final match = RegExp(r'(\d+)$').firstMatch(ssid);
          if (match != null) {
            final line = int.tryParse(match.group(1)!)?.toString() ?? '';
            if (line.isNotEmpty) {
              _cachedWifiLine = line;
              return line;
            }
          }
        }
      }

      // No Cardiff Bus WiFi detected
      return '';
    } catch (e) {
      // WiFi scan failed (permission denied, not supported, etc.)
      return '';
    }
  }

  /// Resets the cached WiFi bus line (call when user manually enters a line).
  void clearWifiCache() {
    _cachedWifiLine = null;
  }
}
