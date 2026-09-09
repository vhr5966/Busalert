/// Repository for parsing calendar_dates.txt GTFS service exceptions.
///
/// Reads today's service exceptions, cross-references with trips.txt to find
/// the affected route_ids, then resolves human-readable route short names
/// from routes.txt.
///
/// Usage:
/// ```dart
/// final repo = ServiceAlertsRepository();
/// final alerts = await repo.getTodaysAlerts();
/// ```
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/gtfs_model.dart';
import 'bods_repository.dart';

class ServiceAlertsRepository {
  final BodsRepository _bodsRepository;

  ServiceAlertsRepository({BodsRepository? bodsRepository})
      : _bodsRepository = bodsRepository ?? BodsRepository();

  // ── In-memory cache ─────────────────────────────────────────────────────
  List<ServiceAlert>? _cachedAlerts;
  String? _cachedDate;

  /// Returns genuine [ServiceAlert]s derived from GTFS calendar_dates.txt and live BODS telemetry.
  Future<List<ServiceAlert>> getTodaysAlerts({String? forceDate}) async {
    final today = forceDate ?? _todayKey();
    if (_cachedAlerts != null && _cachedDate == today) {
      return _cachedAlerts!;
    }

    try {
      final calendarStr = await rootBundle.loadString('calendar_dates.txt');
      final tripsStr = await rootBundle.loadString('trips.txt');
      final routesStr = await rootBundle.loadString('routes.txt');

      final gtfsAlerts = await compute(
        _parseAlerts,
        _ParseArgs(
          calendarCsv: calendarStr,
          tripsCsv: tripsStr,
          routesCsv: routesStr,
          today: today,
        ),
      );

      // ── Also fetch real live vehicle delays from BODS ─────────────────
      final List<ServiceAlert> liveAlerts = [];
      try {
        final liveBuses = await _bodsRepository.getAllVehicles();
        final Set<String> delayedRoutes = {};

        for (final bus in liveBuses) {
          final delay = bus.delayMinutes ?? 0.0;
          if (delay >= 3.0 && bus.lineRef.isNotEmpty && !delayedRoutes.contains(bus.lineRef)) {
            delayedRoutes.add(bus.lineRef);
            liveAlerts.add(
              ServiceAlert(
                routeShortName: bus.lineRef,
                exceptionType: 3,
                customMessage: 'Route ${bus.lineRef} — Live Traffic Delay (+${delay.round()}m)',
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ Live vehicle alerts error: $e');
      }

      final combined = [...liveAlerts, ...gtfsAlerts];
      _cachedAlerts = combined;
      _cachedDate = today;
      return combined;
    } catch (e) {
      debugPrint('⚠️ ServiceAlertsRepository error: $e');
      return [];
    }
  }

  /// YYYYMMDD key for today.
  static String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}

// ── Background isolate helpers ─────────────────────────────────────────────

class _ParseArgs {
  final String calendarCsv;
  final String tripsCsv;
  final String routesCsv;
  final String today;

  const _ParseArgs({
    required this.calendarCsv,
    required this.tripsCsv,
    required this.routesCsv,
    required this.today,
  });
}

/// Pure function executed in a background isolate via [compute].
List<ServiceAlert> _parseAlerts(_ParseArgs args) {
  // ── Step 1: Find service_ids with exceptions today ───────────────────
  final Map<String, int> serviceExceptions = {};

  final calLines = const LineSplitter().convert(args.calendarCsv);
  if (calLines.isEmpty) return [];

  final calHeader = _splitCsv(calLines.first);
  final svcIdx = calHeader.indexOf('service_id');
  final dateIdx = calHeader.indexOf('date');
  final exTypeIdx = calHeader.indexOf('exception_type');
  if (svcIdx < 0 || dateIdx < 0 || exTypeIdx < 0) return [];

  bool foundToday = false;

  // Check if today exists in calendar_dates.txt
  for (int i = 1; i < calLines.length; i++) {
    final line = calLines[i].trim();
    if (line.isEmpty) continue;
    final row = _splitCsv(line);
    if (row.length > dateIdx && row[dateIdx] == args.today) {
      foundToday = true;
      break;
    }
  }

  // If today is not in calendar_dates.txt, there are no holiday cancellations today
  if (!foundToday) {
    return [];
  }

  for (int i = 1; i < calLines.length; i++) {
    final line = calLines[i].trim();
    if (line.isEmpty) continue;
    final row = _splitCsv(line);
    if (row.length <= exTypeIdx) continue;

    final date = row[dateIdx];
    if (date != args.today) continue;

    final svcId = row[svcIdx];
    final exType = int.tryParse(row[exTypeIdx]) ?? 0;
    if (exType == 0) continue;

    serviceExceptions[svcId] = exType;
  }

  if (serviceExceptions.isEmpty) return [];

  // ── Step 2: Map route_id → set of all service_ids via trips.txt ───────
  final Map<String, Set<String>> routeAllServices = {};

  final tripLines = const LineSplitter().convert(args.tripsCsv);
  if (tripLines.isNotEmpty) {
    final tripHeader = _splitCsv(tripLines.first);
    final rIdIdx = tripHeader.indexOf('route_id');
    final sIdIdx = tripHeader.indexOf('service_id');

    if (rIdIdx >= 0 && sIdIdx >= 0) {
      for (int i = 1; i < tripLines.length; i++) {
        final line = tripLines[i].trim();
        if (line.isEmpty) continue;
        final row = _splitCsv(line);
        if (row.length <= rIdIdx || row.length <= sIdIdx) continue;

        final routeId = row[rIdIdx];
        final svcId = row[sIdIdx];
        routeAllServices.putIfAbsent(routeId, () => <String>{}).add(svcId);
      }
    }
  }

  // ── Step 3: Map route_id → short name via routes.txt ─────────────────
  final Map<String, String> routeShortNames = {};

  final routeLines = const LineSplitter().convert(args.routesCsv);
  if (routeLines.isNotEmpty) {
    final routeHeader = _splitCsv(routeLines.first);
    final rIdIdx = routeHeader.indexOf('route_id');
    final rsnIdx = routeHeader.indexOf('route_short_name');

    if (rIdIdx >= 0 && rsnIdx >= 0) {
      for (int i = 1; i < routeLines.length; i++) {
        final line = routeLines[i].trim();
        if (line.isEmpty) continue;
        final row = _splitCsv(line);
        if (row.length <= rsnIdx) continue;

        final routeId = row[rIdIdx];
        routeShortNames[routeId] = row[rsnIdx];
      }
    }
  }

  // ── Step 4: Evaluate overall route service status accurately ─────────
  final Map<String, ServiceAlert> alertMap = {};

  for (final entry in routeAllServices.entries) {
    final routeId = entry.key;
    final allServices = entry.value;
    final shortName = routeShortNames[routeId] ?? routeId;

    int addedCount = 0;
    int removedCount = 0;

    for (final sId in allServices) {
      final ex = serviceExceptions[sId];
      if (ex == 1) addedCount++;
      if (ex == 2) removedCount++;
    }

    // Only create alert if this route has calendar exceptions today
    if (addedCount > 0 || removedCount > 0) {
      int effectiveExceptionType;
      if (removedCount == allServices.length && addedCount == 0) {
        // Truly ALL services for this route are removed today
        effectiveExceptionType = 2; // No service
      } else if (addedCount > 0 && removedCount == 0) {
        effectiveExceptionType = 1; // Special/added service
      } else {
        // Partial modification or timetable replacement (e.g. Saturday/holiday schedule)
        effectiveExceptionType = 3; // Modified timetable
      }

      alertMap[shortName] = ServiceAlert(
        routeShortName: shortName,
        exceptionType: effectiveExceptionType,
      );
    }
  }

  // Sort: removed-service (2) first, then modified (3), then added (1); then alphabetically
  final result = alertMap.values.toList()
    ..sort((a, b) {
      if (a.exceptionType != b.exceptionType) {
        // Order: 2 (red), 3 (amber), 1 (blue)
        final priorityA = a.exceptionType == 2 ? 0 : (a.exceptionType == 3 ? 1 : 2);
        final priorityB = b.exceptionType == 2 ? 0 : (b.exceptionType == 3 ? 1 : 2);
        return priorityA.compareTo(priorityB);
      }
      return a.routeShortName.compareTo(b.routeShortName);
    });

  return result;
}

/// Minimal CSV splitter (no quote handling needed for calendar_dates.txt).
List<String> _splitCsv(String line) => line.split(',');
