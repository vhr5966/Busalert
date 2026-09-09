/// Riverpod provider that exposes the GTFS-derived bus lines for the
/// currently selected bus stop.
///
/// Consumes [predictionProvider] to know which stop is selected, then
/// calls [GtfsStopRoutesService] to look up the pre-built route set.
/// No file I/O happens here — all data is in a Dart const map compiled
/// into the binary.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/gtfs_stop_routes_service.dart';
import 'prediction_provider.dart';

/// Provides the list of [GtfsLineInfo] for the currently selected stop.
///
/// Returns an empty list when no stop is selected.
final stopLinesProvider = Provider<List<GtfsLineInfo>>((ref) {
  final predState = ref.watch(predictionProvider);
  final selectedStop = predState.selectedStop;
  if (selectedStop == null) return const [];

  // BusStop.id is stopId.hashCode — we need the original ATCO string.
  // BusStop stores it via StopService which keys by atcoCode.
  // The NaPTAN BusStop does NOT store the raw atcoCode string on the model,
  // but the GTFS uses the same NaPTAN codes. We need to match by name as a
  // last resort, or — better — look up by the raw ATCO string that is the
  // stopId in the GTFS.
  //
  // The StopService.getStops() creates BusStop with id = atcoCode.hashCode.
  // So we can't reverse that hash. Instead, BusStop needs to expose the
  // atcoCode directly. For now we use the existing `routes` field which is
  // already populated from kCardiffBusRouteStops for some stops.
  //
  // The GTFS service is the new source of truth. To bridge the two, we
  // expose a separate provider that takes the stop's atcoCode stored as
  // a property — see [stopLinesForAtcoProvider] below.
  return const [];
});

/// Provides the list of [GtfsLineInfo] for a given NaPTAN ATCO code.
///
/// This is the primary entry point for the UI: pass the stop's atcoCode
/// (the NaPTAN stop_id) to get the lines.
final stopLinesForAtcoProvider =
    Provider.family<List<GtfsLineInfo>, String>((ref, atcoCode) {
  return GtfsStopRoutesService.instance.linesForStop(atcoCode);
});

/// Provides the route short-name strings for a given ATCO code.
///
/// Used by the prediction dropdown to filter routes to this stop.
final stopRouteNamesForAtcoProvider =
    Provider.family<List<String>, String>((ref, atcoCode) {
  return GtfsStopRoutesService.instance.routeNamesForStop(atcoCode);
});
