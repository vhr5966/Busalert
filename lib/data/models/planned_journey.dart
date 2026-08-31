/// Model representing a planned transit journey between an origin and destination stop.
///
/// Contains route details, scheduled departure/arrival times, travel duration,
/// intermediate stop count, and real-time delay telemetry.
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class PlannedJourney {
  /// Bus line short name (e.g. "27", "1", "M1").
  final String routeNumber;

  /// Trip headsign or destination (e.g. "Cardiff Central via Albany Rd").
  final String headsign;

  /// Origin stop ATCO code or ID.
  final String originStopId;

  /// Origin stop display name.
  final String originStopName;

  /// Destination stop ATCO code or ID.
  final String destinationStopId;

  /// Destination stop display name.
  final String destinationStopName;

  /// Scheduled departure time at origin stop (e.g. "14:25").
  final String departureTime;

  /// Scheduled arrival time at destination stop (e.g. "14:42").
  final String arrivalTime;

  /// In-transit duration in minutes.
  final int durationMinutes;

  /// Number of intermediate stops along this trip.
  final int stopsCount;

  /// Real-time delay in minutes from BODS (null if no live data).
  final double? delayMinutes;

  /// True if a live vehicle is currently tracked on this trip.
  final bool isLive;

  /// Live vehicle registration or reference.
  final String? vehicleRef;

  const PlannedJourney({
    required this.routeNumber,
    required this.headsign,
    required this.originStopId,
    required this.originStopName,
    required this.destinationStopId,
    required this.destinationStopName,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMinutes,
    required this.stopsCount,
    this.delayMinutes,
    this.isLive = false,
    this.vehicleRef,
  });

  /// Delay status color indicator.
  Color get statusColor {
    if (delayMinutes == null) return Colors.grey;
    if (delayMinutes! <= 2) return kOnTimeGreen;
    if (delayMinutes! <= 10) return kAmberAccent;
    return kDelayRed;
  }

  /// Status badge label.
  String get statusLabel {
    if (delayMinutes == null) return 'Scheduled';
    if (delayMinutes! <= 0) return 'On Time';
    if (delayMinutes! <= 2) return 'On Time (+${delayMinutes!.round()}m)';
    return '+${delayMinutes!.round()} min delay';
  }

  /// Human-readable departure countdown relative to current time.
  String departureCountdown(DateTime now) {
    final parts = departureTime.split(':');
    if (parts.length < 2) return departureTime;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final departureDT = DateTime(now.year, now.month, now.day, hour, minute);
    var diff = departureDT.difference(now).inMinutes;

    if (diff < -60) {
      diff += 24 * 60; // Next day midnight rollover
    }

    if (diff <= 0) return 'Due now';
    if (diff == 1) return 'in 1 min';
    if (diff < 60) return 'in $diff mins';
    final hrs = diff ~/ 60;
    final mins = diff % 60;
    return 'in ${hrs}h ${mins}m';
  }
}
