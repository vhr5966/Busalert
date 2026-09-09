/// GTFS data models for routes, trips, stops, stop times, and shape points.
/// Also contains [ServiceAlert] for today's calendar_dates.txt exceptions.
library;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class GtfsRoute {
  final String routeId;
  final String shortName;
  final String longName;
  final String? colorHex;

  const GtfsRoute({
    required this.routeId,
    required this.shortName,
    required this.longName,
    this.colorHex,
  });

  Color? get color {
    if (colorHex == null || colorHex!.isEmpty || colorHex == 'FFFFFF') return null;
    final hex = colorHex!.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return null;
  }
}

class GtfsTrip {
  final String tripId;
  final String routeId;
  final String serviceId;
  final String shapeId;
  final String headsign;
  final int directionId;

  const GtfsTrip({
    required this.tripId,
    required this.routeId,
    this.serviceId = '',
    required this.shapeId,
    required this.headsign,
    this.directionId = 0,
  });

  /// Evaluates whether this trip operates on a given date / day of week.
  ///
  /// Cardiff Bus GTFS encodes operating days in the service ID:
  /// - `MF`: Monday through Friday only
  /// - `SA`: Saturday only
  /// - `SU`: Sunday only
  /// - `DY` or general: Daily operation
  bool operatesOn(DateTime date) {
    if (serviceId.isEmpty) return true;
    final s = serviceId.toUpperCase();
    final hasMF = s.contains('MF');
    final hasSA = s.contains('SA');
    final hasSU = s.contains('SU');

    // If no specific day-of-week marker is present (e.g. daily, stadium specials, generic mocks), operates every day
    if (!hasMF && !hasSA && !hasSU) return true;

    final weekday = date.weekday; // 1 = Monday, ... 5 = Friday, 6 = Saturday, 7 = Sunday
    if (weekday == 6) {
      return hasSA;
    } else if (weekday == 7) {
      return hasSU;
    } else {
      return hasMF;
    }
  }
}

class GtfsShapePoint {
  final String shapeId;
  final double latitude;
  final double longitude;
  final int sequence;

  const GtfsShapePoint({
    required this.shapeId,
    required this.latitude,
    required this.longitude,
    required this.sequence,
  });

  LatLng get location => LatLng(latitude, longitude);
}

class GtfsStopTime {
  final String tripId;
  final String stopId;
  final int stopSequence;
  final String arrivalTime;
  final String departureTime;

  const GtfsStopTime({
    required this.tripId,
    required this.stopId,
    required this.stopSequence,
    this.arrivalTime = '',
    this.departureTime = '',
  });
}

class GtfsStop {
  final String stopId;
  final String stopName;
  final double latitude;
  final double longitude;

  const GtfsStop({
    required this.stopId,
    required this.stopName,
    required this.latitude,
    required this.longitude,
  });

  LatLng get location => LatLng(latitude, longitude);
}

/// Represents an item in a real-time timetable feed.
class TimetableEntry {
  final String tripId;
  final String routeNumber;
  final String headsign;
  final String stopId;
  final String stopName;
  final String scheduledDeparture; // e.g., "14:25"
  final String? predictedDeparture; // e.g., "14:28"
  final double? delayMinutes;
  final bool isLive;
  final String? vehicleRef;

  const TimetableEntry({
    required this.tripId,
    required this.routeNumber,
    required this.headsign,
    required this.stopId,
    required this.stopName,
    required this.scheduledDeparture,
    this.predictedDeparture,
    this.delayMinutes,
    this.isLive = false,
    this.vehicleRef,
  });

  /// Status badge color based on delay
  Color get statusColor {
    if (delayMinutes == null) return Colors.blueGrey;
    if (delayMinutes! <= 2) return Colors.green;
    if (delayMinutes! <= 10) return Colors.orange;
    return Colors.red;
  }

  /// Status label text
  String get statusLabel {
    if (delayMinutes == null) return 'Scheduled';
    if (delayMinutes! <= 0) return 'On Time';
    if (delayMinutes! <= 2) return 'On Time (+${delayMinutes!.round()}m)';
    return '+${delayMinutes!.round()} min delay';
  }

  /// Human readable minutes until departure relative to current time.
  /// If departure is within 45 minutes, shows countdown ('in 12 mins' / 'Due now').
  /// If departure is more than 45 minutes away, returns formatted departure time ('At 05:40').
  String minutesUntilText(DateTime now) {
    final depTime = predictedDeparture ?? scheduledDeparture;
    final parts = depTime.split(':');
    if (parts.length < 2) return '';
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final departureDT = DateTime(now.year, now.month, now.day, hour, minute);
    var diff = departureDT.difference(now).inMinutes;

    // Handle past midnight rollover if needed
    if (diff < -60) {
      diff += 24 * 60;
    }

    if (diff < -5) return '';
    if (diff <= 0) return 'Due now';
    if (diff == 1) return 'in 1 min';
    if (diff <= 45) return 'in $diff mins';
    return '';
  }
}

/// Represents a today's service exception from calendar_dates.txt.
///
/// [exceptionType]:
/// * 1 = special / added service
/// * 2 = full service cancellation (no service)
/// * 3 = modified / holiday timetable
class ServiceAlert {
  final String routeShortName;
  final int exceptionType;
  final String? customMessage;

  const ServiceAlert({
    required this.routeShortName,
    required this.exceptionType,
    this.customMessage,
  });

  /// Human-readable description for the alert banner.
  String get description {
    if (customMessage != null && customMessage!.isNotEmpty) {
      return customMessage!;
    }
    switch (exceptionType) {
      case 2:
        return 'Route $routeShortName — no service today';
      case 1:
        return 'Route $routeShortName — special service running today';
      case 3:
      default:
        return 'Route $routeShortName — modified timetable';
    }
  }

  /// Severity colour: red for full cancellation, amber for modified, blue for added.
  Color get color {
    switch (exceptionType) {
      case 2:
        return const Color(0xFFD32F2F);
      case 3:
        return const Color(0xFFE65100);
      case 1:
      default:
        return const Color(0xFF1565C0);
    }
  }

  /// Icon for the alert type.
  IconData get icon {
    switch (exceptionType) {
      case 2:
        return Icons.cancel_outlined;
      case 3:
        return Icons.schedule;
      case 1:
      default:
        return Icons.directions_bus;
    }
  }
}
