/// Repository for loading, parsing, and querying official GTFS data files.
///
/// Parses `routes.txt`, `trips.txt`, `stops.txt`, `stop_times.txt`, and `shapes.txt`
/// to extract shape polylines and ordered stop sequences for selected routes.
library;

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/bus_stop.dart';
import '../models/gtfs_model.dart';
import '../models/planned_journey.dart';

class GtfsRepository {
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // Parsed indices
  final List<GtfsRoute> _routes = [];
  final Map<String, List<String>> _shortNameToRouteIds = {};
  final Map<String, List<GtfsTrip>> _tripsByRouteId = {};
  final Map<String, GtfsTrip> _tripsById = {};
  final Map<String, List<GtfsShapePoint>> _shapesById = {};
  final Map<String, List<GtfsStopTime>> _stopTimesByTripId = {};
  final Map<String, List<GtfsStopTime>> _stopTimesByStopId = {};
  final Map<String, GtfsStop> _stopsById = {};

  List<GtfsRoute> get routes => List.unmodifiable(_routes);

  /// Loads GTFS files from assets or provided string content.
  Future<void> loadGtfsData({
    String? routesCsv,
    String? tripsCsv,
    String? stopsCsv,
    String? stopTimesCsv,
    String? shapesCsv,
  }) async {
    if (_isLoaded) return;

    try {
      final routesStr = routesCsv ?? await rootBundle.loadString('routes.txt');
      final tripsStr = tripsCsv ?? await rootBundle.loadString('trips.txt');
      final stopsStr = stopsCsv ?? await rootBundle.loadString('stops.txt');
      final stopTimesStr = stopTimesCsv ?? await rootBundle.loadString('stop_times.txt');
      final shapesStr = shapesCsv ?? await rootBundle.loadString('shapes.txt');

      _parseRoutes(routesStr);
      _parseTrips(tripsStr);
      _parseStops(stopsStr);
      _parseStopTimes(stopTimesStr);
      _parseShapes(shapesStr);

      _isLoaded = true;
      debugPrint('🚌 GTFS data loaded successfully: ${_routes.length} routes, ${_stopsById.length} stops');
    } catch (e) {
      debugPrint('⚠️ Error loading GTFS data: $e');
      rethrow;
    }
  }

  /// Parses CSV line handling quotes.
  List<String> _splitCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  void _parseRoutes(String csvText) {
    final lines = const LineSplitter().convert(csvText);
    if (lines.isEmpty) return;

    final header = _splitCsvLine(lines.first);
    final routeIdIdx = header.indexOf('route_id');
    final shortNameIdx = header.indexOf('route_short_name');
    final longNameIdx = header.indexOf('route_long_name');
    final colorIdx = header.indexOf('route_color');

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final row = _splitCsvLine(line);
      if (row.length <= routeIdIdx) continue;

      final routeId = row[routeIdIdx];
      final shortName = shortNameIdx >= 0 && row.length > shortNameIdx ? row[shortNameIdx] : routeId;
      final longName = longNameIdx >= 0 && row.length > longNameIdx ? row[longNameIdx] : '';
      final colorHex = colorIdx >= 0 && row.length > colorIdx ? row[colorIdx] : null;

      final route = GtfsRoute(
        routeId: routeId,
        shortName: shortName,
        longName: longName,
        colorHex: colorHex,
      );

      _routes.add(route);
      _shortNameToRouteIds.putIfAbsent(shortName, () => []).add(routeId);
    }
  }

  void _parseTrips(String csvText) {
    final lines = const LineSplitter().convert(csvText);
    if (lines.isEmpty) return;

    final header = _splitCsvLine(lines.first);
    final routeIdIdx = header.indexOf('route_id');
    final tripIdIdx = header.indexOf('trip_id');
    final shapeIdIdx = header.indexOf('shape_id');
    final headsignIdx = header.indexOf('trip_headsign');

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final row = _splitCsvLine(line);
      if (row.length <= tripIdIdx) continue;

      final routeId = row[routeIdIdx];
      final tripId = row[tripIdIdx];
      final shapeId = shapeIdIdx >= 0 && row.length > shapeIdIdx ? row[shapeIdIdx] : '';
      final headsign = headsignIdx >= 0 && row.length > headsignIdx ? row[headsignIdx] : '';

      final trip = GtfsTrip(
        tripId: tripId,
        routeId: routeId,
        shapeId: shapeId,
        headsign: headsign,
      );

      _tripsById[tripId] = trip;
      _tripsByRouteId.putIfAbsent(routeId, () => []).add(trip);
    }
  }

  void _parseStops(String csvText) {
    final lines = const LineSplitter().convert(csvText);
    if (lines.isEmpty) return;

    final header = _splitCsvLine(lines.first);
    final stopIdIdx = header.indexOf('stop_id');
    final stopNameIdx = header.indexOf('stop_name');
    final latIdx = header.indexOf('stop_lat');
    final lonIdx = header.indexOf('stop_lon');

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final row = _splitCsvLine(line);
      if (row.length <= stopIdIdx) continue;

      final stopId = row[stopIdIdx];
      final stopName = stopNameIdx >= 0 && row.length > stopNameIdx ? row[stopNameIdx] : stopId;
      final lat = latIdx >= 0 && row.length > latIdx ? double.tryParse(row[latIdx]) ?? 0.0 : 0.0;
      final lon = lonIdx >= 0 && row.length > lonIdx ? double.tryParse(row[lonIdx]) ?? 0.0 : 0.0;

      final stop = GtfsStop(
        stopId: stopId,
        stopName: stopName,
        latitude: lat,
        longitude: lon,
      );

      _stopsById[stopId] = stop;
    }
  }

  void _parseStopTimes(String csvText) {
    final lines = const LineSplitter().convert(csvText);
    if (lines.isEmpty) return;

    final header = _splitCsvLine(lines.first);
    final tripIdIdx = header.indexOf('trip_id');
    final arrivalIdx = header.indexOf('arrival_time');
    final departureIdx = header.indexOf('departure_time');
    final stopIdIdx = header.indexOf('stop_id');
    final seqIdx = header.indexOf('stop_sequence');

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final row = _splitCsvLine(line);
      if (row.length <= stopIdIdx) continue;

      final tripId = row[tripIdIdx];
      final stopId = row[stopIdIdx];
      final arrivalTime = arrivalIdx >= 0 && row.length > arrivalIdx ? row[arrivalIdx] : '';
      final departureTime = departureIdx >= 0 && row.length > departureIdx ? row[departureIdx] : '';
      final seq = seqIdx >= 0 && row.length > seqIdx ? int.tryParse(row[seqIdx]) ?? 0 : 0;

      final stopTime = GtfsStopTime(
        tripId: tripId,
        stopId: stopId,
        stopSequence: seq,
        arrivalTime: arrivalTime,
        departureTime: departureTime,
      );

      _stopTimesByTripId.putIfAbsent(tripId, () => []).add(stopTime);
      _stopTimesByStopId.putIfAbsent(stopId, () => []).add(stopTime);
    }

    // Sort stop times by sequence
    for (final list in _stopTimesByTripId.values) {
      list.sort((a, b) => a.stopSequence.compareTo(b.stopSequence));
    }
  }

  void _parseShapes(String csvText) {
    final lines = const LineSplitter().convert(csvText);
    if (lines.isEmpty) return;

    final header = _splitCsvLine(lines.first);
    final shapeIdIdx = header.indexOf('shape_id');
    final latIdx = header.indexOf('shape_pt_lat');
    final lonIdx = header.indexOf('shape_pt_lon');
    final seqIdx = header.indexOf('shape_pt_sequence');

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final row = _splitCsvLine(line);
      if (row.length <= shapeIdIdx) continue;

      final shapeId = row[shapeIdIdx];
      final lat = latIdx >= 0 && row.length > latIdx ? double.tryParse(row[latIdx]) ?? 0.0 : 0.0;
      final lon = lonIdx >= 0 && row.length > lonIdx ? double.tryParse(row[lonIdx]) ?? 0.0 : 0.0;
      final seq = seqIdx >= 0 && row.length > seqIdx ? int.tryParse(row[seqIdx]) ?? 0 : 0;

      final point = GtfsShapePoint(
        shapeId: shapeId,
        latitude: lat,
        longitude: lon,
        sequence: seq,
      );

      _shapesById.putIfAbsent(shapeId, () => []).add(point);
    }

    // Sort shape points by sequence
    for (final list in _shapesById.values) {
      list.sort((a, b) => a.sequence.compareTo(b.sequence));
    }
  }

  /// Extracts official shape polylines for a route number (e.g., "1" or "27").
  /// Returns empty list if no shape data is available.
  List<List<LatLng>> getShapesForRoute(String routeNumber) {
    final routeIds = _shortNameToRouteIds[routeNumber] ??
        _shortNameToRouteIds[routeNumber.toUpperCase()] ??
        [];

    final List<List<LatLng>> polylines = [];
    final Set<String> processedShapeIds = {};

    for (final routeId in routeIds) {
      final trips = _tripsByRouteId[routeId] ?? [];
      for (final trip in trips) {
        if (trip.shapeId.isEmpty || processedShapeIds.contains(trip.shapeId)) continue;
        processedShapeIds.add(trip.shapeId);

        final shapePoints = _shapesById[trip.shapeId];
        if (shapePoints != null && shapePoints.isNotEmpty) {
          polylines.add(shapePoints.map((pt) => pt.location).toList());
        }
      }
    }

    return polylines;
  }

  /// Extracts official ordered stops for a route number using trip stop_sequence.
  List<BusStop> getStopsForRoute(String routeNumber) {
    final routeIds = _shortNameToRouteIds[routeNumber] ??
        _shortNameToRouteIds[routeNumber.toUpperCase()] ??
        [];

    final Map<String, BusStop> uniqueStopsMap = {};

    for (final routeId in routeIds) {
      final trips = _tripsByRouteId[routeId] ?? [];
      if (trips.isEmpty) continue;

      // Select representative trips to collect stops
      for (final trip in trips) {
        final stopTimes = _stopTimesByTripId[trip.tripId] ?? [];
        for (final st in stopTimes) {
          final gtfsStop = _stopsById[st.stopId];
          if (gtfsStop != null) {
            uniqueStopsMap.putIfAbsent(
              gtfsStop.stopId,
              () => BusStop(
                id: gtfsStop.stopId.hashCode,
                name: gtfsStop.stopName,
                latitude: gtfsStop.latitude,
                longitude: gtfsStop.longitude,
                routes: [routeNumber],
              ),
            );
          }
        }
      }
    }

    return uniqueStopsMap.values.toList();
  }

  /// Returns upcoming scheduled departures for a given [stopId] or stop name / ATCO code.
  /// Option to filter by [routeNumber].
  List<TimetableEntry> getUpcomingDeparturesForStop({
    required String stopId,
    String? routeNumber,
    DateTime? relativeTo,
    int limit = 10,
  }) {
    final now = relativeTo ?? DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    // Find stop ID match
    var stopTimes = _stopTimesByStopId[stopId] ?? [];
    var stopObj = _stopsById[stopId];

    // If direct ID missed, search by matching stop code or stop name
    if (stopTimes.isEmpty) {
      for (final entry in _stopTimesByStopId.entries) {
        if (entry.key.contains(stopId) || stopId.contains(entry.key)) {
          stopTimes = entry.value;
          stopObj = _stopsById[entry.key];
          break;
        }
      }
    }

    if (stopTimes.isEmpty) {
      final query = stopId.toLowerCase();
      for (final s in _stopsById.values) {
        if (s.stopName.toLowerCase().contains(query) ||
            query.contains(s.stopName.toLowerCase())) {
          final found = _stopTimesByStopId[s.stopId] ?? [];
          if (found.isNotEmpty) {
            stopTimes = found;
            stopObj = s;
            break;
          }
        }
      }
    }

    final stopName = stopObj?.stopName ?? (stopId.isNotEmpty ? stopId : 'Bus Stop');

    // Route ID filter
    Set<String>? allowedRouteIds;
    if (routeNumber != null && routeNumber.trim().isNotEmpty) {
      final normalizedRoute = routeNumber.trim();
      final ids = _shortNameToRouteIds[normalizedRoute] ??
          _shortNameToRouteIds[normalizedRoute.toUpperCase()] ??
          [];
      if (ids.isEmpty) return []; // Requested route has no trips for this stop
      allowedRouteIds = ids.toSet();
    }

    final List<TimetableEntry> entries = [];

    for (final st in stopTimes) {
      if (st.departureTime.isEmpty) continue;

      final trip = _tripsById[st.tripId];
      if (trip == null) continue;

      if (allowedRouteIds != null && allowedRouteIds.isNotEmpty) {
        if (!allowedRouteIds.contains(trip.routeId)) continue;
      }

      // Parse HH:mm:ss
      final parts = st.departureTime.split(':');
      if (parts.length < 2) continue;

      final rawH = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final normH = rawH % 24;
      final depMinutes = rawH * 60 + m;

      // Filter to departures from current time window (up to 3 hours ahead)
      // During late-night hours (23:00+), do not include past departures (depMinutes < nowMinutes)
      final isLateNightHour = now.hour >= 23 || now.hour < 5;
      final minBuffer = isLateNightHour ? 0 : 5;
      if (depMinutes < nowMinutes - minBuffer || depMinutes > nowMinutes + 180) {
        continue;
      }

      final formattedDep = '${normH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      final routeShortName = routeNumber ??
          _routes.firstWhere((r) => r.routeId == trip.routeId, orElse: () => GtfsRoute(routeId: trip.routeId, shortName: 'Bus', longName: '')).shortName;

      entries.add(TimetableEntry(
        tripId: st.tripId,
        routeNumber: routeShortName,
        headsign: trip.headsign.isNotEmpty ? trip.headsign : 'Cardiff',
        stopId: st.stopId,
        stopName: stopName,
        scheduledDeparture: formattedDep,
      ));
    }

    // Sort entries by departure time
    entries.sort((a, b) => a.scheduledDeparture.compareTo(b.scheduledDeparture));

    if (entries.length > limit) {
      return entries.sublist(0, limit);
    }
    return entries;
  }

  /// Finds all direct transit journeys from [originStopId] to [destinationStopId].
  ///
  /// Searches all GTFS trips where origin stop sequence < destination stop sequence.
  /// Computes departure/arrival times, duration in minutes, and intermediate stops count.
  /// Optional [preferredRouteNumber] filters results to a specific bus route service.
  List<PlannedJourney> findDirectJourneys({
    required String originStopId,
    required String destinationStopId,
    String? preferredRouteNumber,
    DateTime? relativeTo,
    int limit = 15,
  }) {
    final now = relativeTo ?? DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    // Resolve stops
    final originStop = _stopsById[originStopId];
    final destStop = _stopsById[destinationStopId];
    final originName = originStop?.stopName ?? 'Origin';
    final destName = destStop?.stopName ?? 'Destination';

    final originStopTimes = _stopTimesByStopId[originStopId] ?? [];
    if (originStopTimes.isEmpty) return [];

    final List<PlannedJourney> journeys = [];
    final Set<String> seenTripSignatures = {};

    final normalizedFilter = preferredRouteNumber?.trim().toUpperCase();

    for (final origSt in originStopTimes) {
      final tripId = origSt.tripId;
      final allTripStops = _stopTimesByTripId[tripId] ?? [];
      if (allTripStops.isEmpty) continue;

      // Find destination stop in the same trip
      GtfsStopTime? destSt;
      for (final st in allTripStops) {
        if (st.stopId == destinationStopId) {
          destSt = st;
          break;
        }
      }

      // Must exist and occur AFTER origin
      if (destSt == null || origSt.stopSequence >= destSt.stopSequence) {
        continue;
      }

      final trip = _tripsById[tripId];
      if (trip == null) continue;

      final route = _routes.firstWhere(
        (r) => r.routeId == trip.routeId,
        orElse: () => GtfsRoute(routeId: trip.routeId, shortName: 'Bus', longName: ''),
      );

      // Apply preferred route filter if specified
      if (normalizedFilter != null && normalizedFilter.isNotEmpty) {
        if (route.shortName.trim().toUpperCase() != normalizedFilter) {
          continue;
        }
      }

      // Parse origin departure time
      final depParts = origSt.departureTime.split(':');
      if (depParts.length < 2) continue;
      final origH = int.tryParse(depParts[0]) ?? 0;
      final origM = int.tryParse(depParts[1]) ?? 0;
      final origMinutes = origH * 60 + origM;

      // Filter to upcoming departures (now - 5m up to now + 300m)
      final isLateNight = now.hour >= 23 || now.hour < 5;
      final minBuffer = isLateNight ? 0 : 5;
      if (origMinutes < nowMinutes - minBuffer || origMinutes > nowMinutes + 300) {
        continue;
      }

      // Parse destination arrival time
      final arrParts = destSt.arrivalTime.isNotEmpty
          ? destSt.arrivalTime.split(':')
          : destSt.departureTime.split(':');
      if (arrParts.length < 2) continue;
      final destH = int.tryParse(arrParts[0]) ?? 0;
      final destM = int.tryParse(arrParts[1]) ?? 0;
      final destMinutes = destH * 60 + destM;

      var duration = destMinutes - origMinutes;
      if (duration < 0) duration += 24 * 60; // Rollover if any

      final stopsCount = (destSt.stopSequence - origSt.stopSequence).clamp(1, 99);

      final formattedDep =
          '${(origH % 24).toString().padLeft(2, '0')}:${origM.toString().padLeft(2, '0')}';
      final formattedArr =
          '${(destH % 24).toString().padLeft(2, '0')}:${destM.toString().padLeft(2, '0')}';

      // Deduplicate identical route & departure time entries
      final sig = '${route.shortName}:$formattedDep';
      if (seenTripSignatures.contains(sig)) continue;
      seenTripSignatures.add(sig);

      journeys.add(
        PlannedJourney(
          routeNumber: route.shortName,
          headsign: trip.headsign.isNotEmpty ? trip.headsign : destName,
          originStopId: originStopId,
          originStopName: originName,
          destinationStopId: destinationStopId,
          destinationStopName: destName,
          departureTime: formattedDep,
          arrivalTime: formattedArr,
          durationMinutes: duration,
          stopsCount: stopsCount,
        ),
      );
    }

    // Sort by scheduled departure time
    journeys.sort((a, b) => a.departureTime.compareTo(b.departureTime));

    if (journeys.length > limit) {
      return journeys.sublist(0, limit);
    }
    return journeys;
  }

  /// Finds 1-transfer connecting journeys via City Centre when no single direct bus exists.
  List<PlannedJourney> findConnectingJourneys({
    required String originStopId,
    required String destinationStopId,
    DateTime? relativeTo,
    int limit = 6,
  }) {
    final hubStops = _stopsById.values.where((s) {
      final name = s.stopName.toLowerCase();
      return name.contains('central') ||
          name.contains('kingsway') ||
          name.contains('westgate') ||
          name.contains('greyfriars') ||
          name.contains('customhouse') ||
          name.contains('churchill');
    }).toList();

    if (hubStops.isEmpty) return [];

    final List<PlannedJourney> transferJourneys = [];
    final Set<String> seenSigs = {};

    for (final hub in hubStops.take(6)) {
      final leg1 = findDirectJourneys(
        originStopId: originStopId,
        destinationStopId: hub.stopId,
        relativeTo: relativeTo,
        limit: 3,
      );

      if (leg1.isEmpty) continue;

      final leg2 = findDirectJourneys(
        originStopId: hub.stopId,
        destinationStopId: destinationStopId,
        relativeTo: relativeTo,
        limit: 3,
      );

      if (leg2.isEmpty) continue;

      for (final j1 in leg1) {
        for (final j2 in leg2) {
          final arr1Parts = j1.arrivalTime.split(':');
          final dep2Parts = j2.departureTime.split(':');
          if (arr1Parts.length == 2 && dep2Parts.length == 2) {
            final arr1Min = (int.tryParse(arr1Parts[0]) ?? 0) * 60 + (int.tryParse(arr1Parts[1]) ?? 0);
            final dep2Min = (int.tryParse(dep2Parts[0]) ?? 0) * 60 + (int.tryParse(dep2Parts[1]) ?? 0);

            // Require 3 to 45 mins connection time
            if (dep2Min >= arr1Min + 3 && dep2Min <= arr1Min + 45) {
              final sig = '${j1.routeNumber}-${j2.routeNumber}-${j1.departureTime}';
              if (seenSigs.contains(sig)) continue;
              seenSigs.add(sig);

              final totalDuration = (j1.durationMinutes + (dep2Min - arr1Min) + j2.durationMinutes);
              transferJourneys.add(
                PlannedJourney(
                  routeNumber: '${j1.routeNumber} ➔ ${j2.routeNumber}',
                  headsign: 'Transfer at ${hub.stopName} (${j2.headsign})',
                  originStopId: originStopId,
                  originStopName: j1.originStopName,
                  destinationStopId: destinationStopId,
                  destinationStopName: j2.destinationStopName,
                  departureTime: j1.departureTime,
                  arrivalTime: j2.arrivalTime,
                  durationMinutes: totalDuration,
                  stopsCount: j1.stopsCount + j2.stopsCount,
                ),
              );
            }
          }
        }
      }
      if (transferJourneys.length >= limit) break;
    }

    transferJourneys.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    return transferJourneys.take(limit).toList();
  }

  /// Returns all stops as BusStop objects.
  List<BusStop> getAllStops() {
    return _stopsById.values
        .map(
          (s) => BusStop(
            id: s.stopId.hashCode,
            name: s.stopName,
            latitude: s.latitude,
            longitude: s.longitude,
            routes: const [],
          ),
        )
        .toList();
  }
}

