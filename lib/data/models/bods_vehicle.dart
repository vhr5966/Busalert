/// Model representing a live bus vehicle from the BODS SIRI-VM feed.
///
/// Each vehicle has real-time position, delay, and route information.
/// The `directionRef` field indicates which direction the bus is traveling.
library;

import 'package:flutter/material.dart';

class BodsVehicle {
  final String vehicleRef;
  final String lineRef;
  final String publishedLineName;
  final String destinationRef;
  final String destinationName;
  final String originRef;
  final String originName;
  final double latitude;
  final double longitude;
  final double? bearing;
  final double? delayMinutes;
  final DateTime? recordedAtTime;
  final String? directionRef;
  final String? datedVehicleJourneyRef;

  const BodsVehicle({
    required this.vehicleRef,
    required this.lineRef,
    this.publishedLineName = '',
    this.destinationRef = '',
    this.destinationName = '',
    this.originRef = '',
    this.originName = '',
    required this.latitude,
    required this.longitude,
    this.bearing,
    this.delayMinutes,
    this.recordedAtTime,
    this.directionRef,
    this.datedVehicleJourneyRef,
  });

  /// Formatted destination name without underscores.
  String get formattedDestination {
    if (destinationName.isEmpty) return 'Cardiff City Centre';
    return destinationName.replaceAll('_', ' ');
  }

  /// Formatted origin name without underscores.
  String get formattedOrigin {
    if (originName.isEmpty) return '';
    return originName.replaceAll('_', ' ');
  }

  /// Checks whether this vehicle matches the given route number.
  ///
  /// Handles prefixes (e.g. 'CBUS:27', 'FCYM:304', 'SSWL:132'), case insensitivity,
  /// leading whitespace, and leading zero variations.
  bool matchesRoute(String routeNumber) {
    final target = routeNumber.trim().toLowerCase();
    if (target.isEmpty) return false;

    final ref = lineRef.trim().toLowerCase();
    final name = publishedLineName.trim().toLowerCase();

    // 1. Direct equality
    if (ref == target || name == target) return true;

    // 2. Strip operator prefix (e.g. 'cbus:27' -> '27', 'fcym:304' -> '304')
    final refPart = ref.contains(':') ? ref.split(':').last.trim() : ref;
    final namePart = name.contains(':') ? name.split(':').last.trim() : name;

    if (refPart == target || namePart == target) return true;

    // 3. Leading zero normalization (e.g. '01' vs '1')
    final targetNoZero = target.replaceFirst(RegExp(r'^0+'), '');
    if (targetNoZero.isNotEmpty) {
      if (refPart.replaceFirst(RegExp(r'^0+'), '') == targetNoZero) return true;
      if (namePart.replaceFirst(RegExp(r'^0+'), '') == targetNoZero) return true;
    }

    return false;
  }

  /// Checks whether this bus is within the Cardiff & South Wales regional area.
  bool get isWithinCardiffArea {
    return latitude >= 51.25 &&
        latitude <= 51.80 &&
        longitude >= -3.75 &&
        longitude <= -2.80;
  }

  /// Returns a color based on the delay status.
  Color get delayColor {
    if (delayMinutes == null) return Colors.grey;
    if (delayMinutes! <= 0) return Colors.green;
    if (delayMinutes! <= 5) return Colors.orange;
    return Colors.red;
  }

  /// Returns a label for the delay status.
  String get delayStatus {
    if (delayMinutes == null) return 'Unknown';
    if (delayMinutes! <= 0) return 'On time';
    if (delayMinutes! <= 5) return 'Minor delay';
    return 'Major delay';
  }

  /// Returns a human-readable direction label.
  String get directionLabel {
    if (destinationName.isNotEmpty) {
      return '→ $formattedDestination';
    }
    if (directionRef == null || directionRef!.isEmpty) return '→ In Transit';
    
    final dir = directionRef!.toLowerCase();
    if (dir.contains('inbound') || dir.contains('city')) return '→ City Centre';
    if (dir.contains('outbound') || dir.contains('suburb')) return '→ Suburb';
    if (dir.contains('clockwise')) return '↻ CW';
    if (dir.contains('anticlockwise') || dir.contains('anti-clockwise')) return '↺ CCW';
    if (dir.contains('north')) return '↑ North';
    if (dir.contains('south')) return '↓ South';
    if (dir.contains('east')) return '→ East';
    if (dir.contains('west')) return '← West';
    
    return '→ ${directionRef!}';
  }

  /// Returns an icon based on the direction.
  IconData get directionIcon {
    if (directionRef == null || directionRef!.isEmpty) return Icons.navigation;
    
    final dir = directionRef!.toLowerCase();
    if (dir.contains('inbound') || dir.contains('city')) return Icons.arrow_back;
    if (dir.contains('outbound') || dir.contains('suburb')) return Icons.arrow_forward;
    if (dir.contains('clockwise')) return Icons.rotate_right;
    if (dir.contains('anticlockwise') || dir.contains('anti-clockwise')) return Icons.rotate_left;
    if (dir.contains('north')) return Icons.arrow_upward;
    if (dir.contains('south')) return Icons.arrow_downward;
    if (dir.contains('east')) return Icons.arrow_forward;
    if (dir.contains('west')) return Icons.arrow_back;
    
    return Icons.navigation;
  }

  /// Creates a [BodsVehicle] from a JSON map.
  factory BodsVehicle.fromJson(Map<String, dynamic> json) {
    return BodsVehicle(
      vehicleRef: json['vehicleRef'] as String? ?? '',
      lineRef: json['lineRef'] as String? ?? '',
      publishedLineName: json['publishedLineName'] as String? ?? '',
      destinationRef: json['destinationRef'] as String? ?? '',
      destinationName: json['destinationName'] as String? ?? '',
      originRef: json['originRef'] as String? ?? '',
      originName: json['originName'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      bearing: (json['bearing'] as num?)?.toDouble(),
      delayMinutes: (json['delayMinutes'] as num?)?.toDouble(),
      recordedAtTime: json['recordedAtTime'] != null
          ? DateTime.tryParse(json['recordedAtTime'] as String)
          : null,
      directionRef: json['directionRef'] as String?,
    );
  }

  /// Serializes to JSON.
  Map<String, dynamic> toJson() {
    return {
      'vehicleRef': vehicleRef,
      'lineRef': lineRef,
      'publishedLineName': publishedLineName,
      'destinationRef': destinationRef,
      'destinationName': destinationName,
      'originRef': originRef,
      'originName': originName,
      'latitude': latitude,
      'longitude': longitude,
      'bearing': bearing,
      'delayMinutes': delayMinutes,
      'recordedAtTime': recordedAtTime?.toIso8601String(),
      'directionRef': directionRef,
    };
  }

  /// Parses an ISO 8601 duration string (e.g., "PT5M30S" or "-PT2M") to minutes.
  static double? parseIso8601Duration(String? duration) {
    if (duration == null || duration.isEmpty) return null;
    
    final isNegative = duration.startsWith('-') || duration.contains('-P');
    final cleaned = duration
        .replaceFirst('-', '')
        .replaceFirst('PT', '')
        .replaceFirst('P', '');
    
    double minutes = 0;
    double seconds = 0;
    
    // Parse hours
    final hoursMatch = RegExp(r'(\d+)H').firstMatch(cleaned);
    if (hoursMatch != null) {
      minutes += double.parse(hoursMatch.group(1)!) * 60;
    }
    
    // Parse minutes
    final minutesMatch = RegExp(r'(\d+)M').firstMatch(cleaned);
    if (minutesMatch != null) {
      minutes += double.parse(minutesMatch.group(1)!);
    }
    
    // Parse seconds
    final secondsMatch = RegExp(r'(\d+)S').firstMatch(cleaned);
    if (secondsMatch != null) {
      seconds += double.parse(secondsMatch.group(1)!);
    }
    
    final total = minutes + (seconds / 60);
    return isNegative ? -total : total;
  }

  @override
  String toString() => 'BodsVehicle(line: $lineRef, delay: ${delayMinutes?.toStringAsFixed(1)} min, '
      'lat: ${latitude.toStringAsFixed(4)}, lng: ${longitude.toStringAsFixed(4)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BodsVehicle &&
          runtimeType == other.runtimeType &&
          vehicleRef == other.vehicleRef;

  @override
  int get hashCode => vehicleRef.hashCode;
}

