/// Unified Live Transit Map screen.
///
/// Combines live moving buses (BODS API) and bus stops (NaPTAN) into one
/// smooth, interactive city map.
///
/// Features:
/// - Real-time moving bus markers with route numbers & directional heading arrows
/// - Bus stop markers with viewport-based filtering for 60fps performance
/// - Quick filter bar: All / Live Buses Only / Stops Only / Route Filter
/// - Slide-up sheet showing live departures for stops or vehicle journey details
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../data/models/bods_vehicle.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/repositories/timetable_repository.dart';
import '../../timetable/screens/route_timetable_screen.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../../tracking/screens/live_tracking_screen.dart';
import '../../tracking/services/gps_tracker.dart';
import '../providers/live_buses_provider.dart';
import '../providers/map_provider.dart';
import '../widgets/locate_me_button.dart';

const LatLng _kCardiffCentre = LatLng(51.4816, -3.1791);
final TimetableRepository _timetableRepo = TimetableRepository();

enum MapFilterType { all, liveBuses, stops }

class UnifiedTransitMapScreen extends ConsumerStatefulWidget {
  const UnifiedTransitMapScreen({super.key});

  @override
  ConsumerState<UnifiedTransitMapScreen> createState() =>
      _UnifiedTransitMapScreenState();
}

class _UnifiedTransitMapScreenState
    extends ConsumerState<UnifiedTransitMapScreen> {
  final MapController _mapController = MapController();
  MapFilterType _activeFilter = MapFilterType.all;
  String? _selectedRouteFilter;
  LatLngBounds? _currentBounds;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(mapProvider.notifier).loadStops();
      ref.read(liveBusesProvider.notifier).refresh();
    });
  }

  void _showStopBottomSheet(BusStop stop) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder(
          future: _timetableRepo.getRealTimeTimetable(stop: stop),
          builder: (context, snapshot) {
            final departures = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kCardiffBlue.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on, color: kCardiffBlue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stop.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                stop.routes.isNotEmpty
                                    ? 'Lines: ${stop.routes.join(', ')}'
                                    : 'Cardiff Bus Stop',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const Text(
                      'Upcoming Departures',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else if (departures.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'No active departures found for this stop right now.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      )
                    else
                      ...departures.take(4).map((dep) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.of(context).pop(); // Close bottom sheet
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RouteTimetableScreen(
                                    routeNumber: dep.routeNumber,
                                    stop: stop,
                                    initialTime: dep.scheduledDeparture,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: kCardiffBlue,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      dep.routeNumber,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      dep.headsign,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    dep.minutesUntilText(DateTime.now()),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: kCardiffBlue,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showVehicleBottomSheet(BodsVehicle vehicle) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kCardiffBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Bus ${vehicle.lineRef}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.destinationName.isNotEmpty
                                ? vehicle.destinationName
                                : 'Cardiff Service',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Vehicle ${vehicle.vehicleRef} • Live GPS',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.speed, size: 18, color: Color(0xFF475569)),
                      const SizedBox(width: 8),
                      Text(
                        'Bearing: ${vehicle.bearing != null ? '${vehicle.bearing!.toStringAsFixed(0)}°' : 'N/A'} • Line ${vehicle.lineRef}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);
    final liveBusesState = ref.watch(liveBusesProvider);

    final showBuses = _activeFilter == MapFilterType.all ||
        _activeFilter == MapFilterType.liveBuses;
    final showStops =
        _activeFilter == MapFilterType.all || _activeFilter == MapFilterType.stops;

    // Filter live buses
    var buses = liveBusesState.vehicles;
    if (_selectedRouteFilter != null) {
      buses = buses.where((b) => b.lineRef == _selectedRouteFilter).toList();
    }

    // Filter stops in viewport
    var stops = mapState.stops;
    if (_currentBounds != null) {
      stops = stops
          .where((s) => _currentBounds!.contains(LatLng(s.latitude, s.longitude)))
          .toList();
    } else {
      stops = stops.take(200).toList();
    }

    final markers = <Marker>[];

    // Add Bus Stop Markers
    if (showStops) {
      for (final stop in stops) {
        markers.add(
          Marker(
            point: LatLng(stop.latitude, stop.longitude),
            width: 14,
            height: 14,
            child: GestureDetector(
              onTap: () {
                _mapController.move(LatLng(stop.latitude, stop.longitude), 16.0);
                _showStopBottomSheet(stop);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: kCardiffBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    // Add Live Moving Bus Markers
    if (showBuses) {
      for (final bus in buses) {
        markers.add(
          Marker(
            point: LatLng(bus.latitude, bus.longitude),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () {
                _mapController.move(LatLng(bus.latitude, bus.longitude), 16.0);
                _showVehicleBottomSheet(bus);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(70),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        bus.lineRef,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (_userLocation != null) {
      markers.add(buildUserLocationMarker(_userLocation!));
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _kCardiffCentre,
              initialZoom: 13.0,
              onPositionChanged: (camera, hasGesture) {
                setState(() {
                  _currentBounds = camera.visibleBounds;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.busalert',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // ── Top Floating Filter Bar ─────────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(235),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildFilterChip('All', MapFilterType.all),
                  const SizedBox(width: 6),
                  _buildFilterChip('Live Buses (${buses.length})', MapFilterType.liveBuses),
                  const SizedBox(width: 6),
                  _buildFilterChip('Stops', MapFilterType.stops),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () {
                      ref.read(liveBusesProvider.notifier).refresh();
                      ref.read(mapProvider.notifier).refreshDelayData();
                    },
                    tooltip: 'Refresh live positions',
                  ),
                ],
              ),
            ),
          ),

          // ── Live Tracking Floating Status / Control ─────────────────
          Positioned(
            bottom: 20,
            left: 16,
            right: 80,
            child: Builder(
              builder: (context) {
                final trackingState = ref.watch(trackingProvider);

                if (trackingState is TrackingSearching) {
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LiveTrackingScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'GPS & WiFi Tracker Active',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Scanning Cardiff Bus SSIDs & boarding speed...',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  );
                }

                if (trackingState is TrackingOnBus) {
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LiveTrackingScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_bus, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Onboard Line ${trackingState.busLine.isNotEmpty ? trackingState.busLine : 'Bus'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Boarded at ${trackingState.boardStop.name}',
                                  style: const TextStyle(
                                    color: Color(0xFFDCFCE7),
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  );
                }

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final consented = await GpsTracker.showGpsConsentDialog(context);
                      if (!context.mounted || !consented) return;

                      await ref.read(trackingProvider.notifier).startTracking();

                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LiveTrackingScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_tethering, color: Color(0xFF38BDF8), size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Live Ride Tracker',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Locate Me Floating Button ───────────────────────────────
          Positioned(
            bottom: 20,
            right: 16,
            child: LocateMeButton(
              mapController: _mapController,
              onLocated: (loc) {
                setState(() => _userLocation = loc);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, MapFilterType type) {
    final isSelected = _activeFilter == type;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _activeFilter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kCardiffBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF334155),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
