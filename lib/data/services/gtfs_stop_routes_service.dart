/// Service that resolves which bus lines serve a given stop, using
/// the pre-built GTFS join map (stop_times -> trips -> routes).
///
/// The map is built once at compile time (see gtfs_stop_routes.dart) by
/// joining stop_times.txt through trips.txt to routes.txt. No file I/O
/// happens at runtime — the data is compiled into the binary as a Dart const.
library;

import 'package:flutter/material.dart';

import '../gtfs_stop_routes.dart';

/// Lightweight value object describing a bus line for display purposes.
class GtfsLineInfo {
  /// GTFS route_id, e.g. "CB:30", "NB:30".
  final String routeId;

  /// Route short name for display, e.g. "30".
  final String shortName;

  /// GTFS agency_id, e.g. "CB" (Cardiff Bus), "NB" (Newport Bus).
  final String agencyId;

  /// Background color parsed from route_color in routes.txt.
  /// Falls back to [_kFallbackColor] if the hex string is empty or invalid.
  final Color backgroundColor;

  /// Text/icon color parsed from route_text_color in routes.txt.
  /// Falls back to [_kFallbackTextColor] if empty or invalid.
  final Color textColor;

  /// Direction id (0 or 1) from GTFS trips.txt.
  /// Null means direction data is not available (should not happen in practice).
  final int? directionId;

  /// Headsign text, e.g. "City Centre" or "Gabalfa".
  /// Empty string if no headsign data is available.
  final String headsign;

  const GtfsLineInfo({
    required this.routeId,
    required this.shortName,
    required this.agencyId,
    required this.backgroundColor,
    required this.textColor,
    this.directionId,
    this.headsign = '',
  });
}

// ── Fallback colors ──────────────────────────────────────────────────────────
const Color _kFallbackColor = Color(0xFF9E9E9E); // neutral grey
const Color _kFallbackTextColor = Colors.white;

class GtfsStopRoutesService {
  GtfsStopRoutesService._();

  static final GtfsStopRoutesService instance = GtfsStopRoutesService._();

  // Pre-parse all route colors once on first access (keyed by route_id now).
  late final Map<String, _RouteColors> _colorCache = _buildColorCache();

  Map<String, _RouteColors> _buildColorCache() {
    final cache = <String, _RouteColors>{};
    for (final entry in kGtfsRouteColors.entries) {
      cache[entry.key] = _RouteColors(
        bg: _parseColor(entry.value.colorHex, _kFallbackColor),
        fg: _parseColor(entry.value.textColorHex, _kFallbackTextColor),
      );
    }
    return cache;
  }

  static Color _parseColor(String hex, Color fallback) {
    final clean = hex.trim().replaceAll('#', '');
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      if (value != null) return Color(value);
    }
    return fallback;
  }

  GtfsLineInfo _infoFor(
    String routeId,
    String shortName,
    String agencyId, {
    int? directionId,
    String headsign = '',
  }) {
    final colors = _colorCache[routeId];
    return GtfsLineInfo(
      routeId: routeId,
      shortName: shortName,
      agencyId: agencyId,
      backgroundColor: colors?.bg ?? _kFallbackColor,
      textColor: colors?.fg ?? _kFallbackTextColor,
      directionId: directionId,
      headsign: headsign,
    );
  }

  /// Returns one [GtfsLineInfo] per distinct route at [stopId] (no direction
  /// detail). Naturally sorted. Returns empty list if stop has no lines.
  /// 
  /// NOTE: If multiple agencies use the same number (CB:30, NB:30), they
  /// appear as separate entries here (not merged).
  List<GtfsLineInfo> linesForStop(String stopId) {
    final entries = kGtfsStopDirections[stopId];
    if (entries == null || entries.isEmpty) return const [];
    
    // Deduplicate by route_id (ignore direction for this method)
    final seen = <String>{};
    final result = <GtfsLineInfo>[];
    for (final e in entries) {
      if (seen.add(e.routeId)) {
        result.add(_infoFor(e.routeId, e.shortName, e.agencyId));
      }
    }
    return result;
  }

  /// Returns [GtfsLineInfo] entries for [stopId] with full directional detail.
  ///
  /// - Routes with **both** directions at this stop appear **twice**, each
  ///   carrying the correct [GtfsLineInfo.directionId] and
  ///   [GtfsLineInfo.headsign] (e.g. "City Centre" / "Gabalfa").
  /// - Routes with only one direction appear once.
  /// - Different agencies with the same number (CB:30, NB:30) are kept separate.
  /// - List is naturally sorted (route name, then agency, then directionId).
  /// - Returns empty list if stop has no scheduled lines.
  List<GtfsLineInfo> directionalLinesForStop(String stopId) {
    final entries = kGtfsStopDirections[stopId];
    if (entries == null || entries.isEmpty) return const [];
    return entries
        .map((e) => _infoFor(
              e.routeId,
              e.shortName,
              e.agencyId,
              directionId: e.directionId,
              headsign: e.headsign,
            ))
        .toList();
  }

  /// Returns the route short names (strings) for [stopId].
  ///
  /// Useful when only the names are needed (e.g. for the prediction dropdown).
  List<String> routeNamesForStop(String stopId) {
    return kGtfsStopRouteNames[stopId] ?? const [];
  }

  /// True if [stopId] has at least one scheduled line.
  bool hasLines(String stopId) {
    final routes = kGtfsStopRouteNames[stopId];
    return routes != null && routes.isNotEmpty;
  }
}

class _RouteColors {
  final Color bg;
  final Color fg;
  const _RouteColors({required this.bg, required this.fg});
}
