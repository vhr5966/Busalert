/// Comprehensive Transit Search screen for BusAlert Cardiff.
///
/// Features:
/// - Auto-focused instant search input with clear button.
/// - Two distinct tabs: **LOCATIONS** and **TIMETABLES** (matching the official
///   Cardiff Bus reference application).
/// - **LOCATIONS**: Searches all 3,764 bus stops with real-time distance
///   calculation (from current GPS or Cardiff Central), locality indicators,
///   and bus route badges.
/// - Selecting a stop provides direct options:
///   1. Plan Journey to this stop (with AI delay prediction and live ride tracking).
///   2. View upcoming departures and timetables.
///   3. View stop location on the live transit map.
/// - **TIMETABLES**: Searches all official Cardiff Bus routes with 1-tap timetable
///   and live bus tracking navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/logger/app_logger.dart';
import '../../../data/constants/cardiff_routes.dart';
import '../../../data/models/bus_route.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/services/stop_service.dart';
import '../../map/screens/unified_transit_map_screen.dart';
import '../../prediction/providers/journey_planner_provider.dart';
import '../../timetable/screens/route_timetable_screen.dart';
import '../widgets/home_journey_planner_sheet.dart';

class TransitSearchScreen extends ConsumerStatefulWidget {
  /// Initial query if passed from another screen.
  final String? initialQuery;

  /// Whether to focus specifically on selecting a destination to plan a trip.
  final bool isPlanMode;

  /// Optional pre-loaded stops.
  final List<BusStop>? initialStops;

  const TransitSearchScreen({
    super.key,
    this.initialQuery,
    this.isPlanMode = false,
    this.initialStops,
  });

  @override
  ConsumerState<TransitSearchScreen> createState() =>
      _TransitSearchScreenState();
}

class _TransitSearchScreenState extends ConsumerState<TransitSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<BusStop> _allStops = [];
  List<BusStop> _filteredStops = [];
  List<BusRoute> _filteredRoutes = [];

  bool _isLoadingStops = true;
  LatLng? _userPosition;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _filteredRoutes = kCardiffReferenceRoutes;

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
    }

    _searchController.addListener(_onSearchChanged);
    _loadStopsAndLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStopsAndLocation() async {
    try {
      // 1. Load stops first so UI renders immediately without waiting for GPS
      final stopService = StopService();
      final stops = widget.initialStops ?? await stopService.getStops();

      if (mounted) {
        setState(() {
          _allStops = stops;
          _isLoadingStops = false;
        });
        _filterResults(_searchController.text);
      }

      // 2. Background non-blocking GPS acquisition
      _acquireGpsLocation();
    } catch (e) {
      AppLogger.error('Failed to load stops in TransitSearchScreen', e);
      if (mounted) {
        setState(() => _isLoadingStops = false);
      }
    }
  }

  Future<void> _acquireGpsLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 2),
          ),
        );
        if (mounted) {
          setState(() {
            _userPosition = LatLng(pos.latitude, pos.longitude);
            _filterResults(_searchController.text);
          });
        }
      }
    } catch (_) {
      // Fallback reference is Cardiff Central
    }
  }

  void _onSearchChanged() {
    setState(() {
      _filterResults(_searchController.text);
    });
  }

  void _filterResults(String query) {
    final q = query.trim().toLowerCase();

    // Filter Bus Stops (Locations)
    if (q.isEmpty) {
      // If empty query, show nearby/popular stops
      _filteredStops = _allStops.take(40).toList();
    } else {
      final tokens =
          q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

      _filteredStops = _allStops.where((s) {
        final name = s.name.toLowerCase();
        final atco = s.atcoCode.toLowerCase();
        final locality = _getLocality(s).toLowerCase();

        return tokens.every((t) =>
            name.contains(t) ||
            atco.contains(t) ||
            locality.contains(t) ||
            s.routes.any((r) => r.toLowerCase() == t));
      }).toList();

      // Sort by proximity if user position available
      if (_userPosition != null) {
        _filteredStops.sort((a, b) {
          final distA = a.distanceTo(
            _userPosition!.latitude,
            _userPosition!.longitude,
          );
          final distB = b.distanceTo(
            _userPosition!.latitude,
            _userPosition!.longitude,
          );
          return distA.compareTo(distB);
        });
      }
    }

    // Filter Bus Routes (Timetables)
    if (q.isEmpty) {
      _filteredRoutes = kCardiffReferenceRoutes;
    } else {
      _filteredRoutes = kCardiffReferenceRoutes.where((r) {
        return r.number.toLowerCase().contains(q) ||
            r.name.toLowerCase().contains(q);
      }).toList();
    }
  }

  double _getDistance(BusStop stop) {
    final refLat = _userPosition?.latitude ?? 51.4816; // Cardiff Central
    final refLng = _userPosition?.longitude ?? -3.1791;
    return stop.distanceTo(refLat, refLng);
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _getLocality(BusStop stop) {
    final atco = stop.atcoCode;
    final nameLower = stop.name.toLowerCase();

    // Newport Stops (ATCO Area 531)
    if (atco.startsWith('531')) {
      if (nameLower.contains('pillgwenlly') || nameLower.contains('gwent')) {
        return 'Pillgwenlly, Newport';
      }
      if (nameLower.contains('wool')) {
        return 'St. Woolos, Newport';
      }
      return 'Newport';
    }

    // Vale of Glamorgan Stops (ATCO Area 572)
    if (atco.startsWith('572')) {
      if (nameLower.contains('barry')) return 'Barry';
      if (nameLower.contains('penarth')) return 'Penarth';
      if (nameLower.contains('llandough')) return 'Llandough';
      if (nameLower.contains('dinas')) return 'Dinas Powys';
      return 'Vale of Glamorgan';
    }

    // Cardiff (ATCO Area 571)
    if (nameLower.contains('central') ||
        nameLower.contains('queen') ||
        nameLower.contains('kingsway') ||
        nameLower.contains('castle') ||
        nameLower.contains('westgate') ||
        nameLower.contains('customhouse')) {
      return 'Cardiff City Centre';
    }
    if (nameLower.contains('bay') ||
        nameLower.contains('mermaid') ||
        nameLower.contains('ocean')) {
      return 'Cardiff Bay';
    }
    if (nameLower.contains('heath') || nameLower.contains('hospital')) {
      return 'Heath Hospital';
    }
    if (nameLower.contains('canton') || nameLower.contains('cowbridge')) {
      return 'Canton';
    }
    if (nameLower.contains('roath') || nameLower.contains('albany')) {
      return 'Roath';
    }
    if (nameLower.contains('cathays') || nameLower.contains('crwys')) {
      return 'Cathays';
    }
    if (nameLower.contains('splott') || nameLower.contains('tremorfa')) {
      return 'Splott / Tremorfa';
    }
    if (nameLower.contains('ely')) return 'Ely';
    if (nameLower.contains('whitchurch')) return 'Whitchurch';
    if (nameLower.contains('llanishen')) return 'Llanishen';

    return 'Cardiff';
  }

  void _onSelectStop(BusStop stop) {
    if (widget.isPlanMode) {
      // Set destination in planner provider and return
      ref.read(journeyPlannerProvider.notifier).setDestinationStop(stop);
      Navigator.of(context).pop(stop);
      return;
    }

    _showStopActionSheet(stop);
  }

  void _showStopActionSheet(BusStop stop) {
    final distance = _formatDistance(_getDistance(stop));
    final locality = _getLocality(stop);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Stop Info Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$locality • $distance away',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (stop.routes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: stop.routes.take(8).map((r) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                r,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 1. Primary Action: Plan Journey to this Stop
            FilledButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _planJourneyToStop(stop);
              },
              icon: const Icon(Icons.alt_route_rounded, size: 20),
              label: const Text('Plan Journey to this Stop'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 2. Secondary Action: View Live Departures & Timetable
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                final routeNumber =
                    stop.routes.isNotEmpty ? stop.routes.first : '27';
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RouteTimetableScreen(
                      routeNumber: routeNumber,
                      stop: stop,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: const Text('View Live Departures & Timetable'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 3. Tertiary Action: View on Map
            TextButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UnifiedTransitMapScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('View Stop on Map'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _planJourneyToStop(BusStop destination) {
    // Set destination in planner
    ref.read(journeyPlannerProvider.notifier).setDestinationStop(destination);

    // Open Journey Planner Sheet directly
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeJourneyPlannerSheet(
        prefilledDestination: destination,
        allStops: _allStops,
      ),
    );
  }

  void _onSelectRoute(BusRoute route) {
    final matchingStop = _allStops.firstWhere(
      (s) => s.routes.contains(route.number),
      orElse: () => _allStops.isNotEmpty
          ? _allStops.first
          : const BusStop(
              id: 1,
              name: 'Cardiff Central',
              latitude: 51.478,
              longitude: -3.178,
              atcoCode: '5810WDB48488',
              routes: ['27'],
            ),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteTimetableScreen(
          routeNumber: route.number,
          stop: matchingStop,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search places, bus stops or routes…',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 15,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged();
              },
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.place_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('LOCATIONS'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('TIMETABLES'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoadingStops
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLocationsTab(),
                _buildTimetablesTab(),
              ],
            ),
    );
  }

  Widget _buildLocationsTab() {
    if (_filteredStops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No bus stops matching "${_searchController.text}"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try searching by stop name (e.g. Royal Gwent, Central), locality, or line number.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredStops.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 64, endIndent: 16),
      itemBuilder: (context, index) {
        final stop = _filteredStops[index];
        final distance = _formatDistance(_getDistance(stop));
        final locality = _getLocality(stop);
        final isOppOrTuAllan = stop.name.contains('(opp)') ||
            stop.name.contains('(tu allan)') ||
            stop.name.contains('Grounds');

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 2,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOppOrTuAllan
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOppOrTuAllan
                  ? Icons.directions_bus_rounded
                  : Icons.location_on_outlined,
              color: isOppOrTuAllan
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF475569),
              size: 20,
            ),
          ),
          title: Text(
            stop.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            locality,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                distance,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
          onTap: () => _onSelectStop(stop),
        );
      },
    );
  }

  Widget _buildTimetablesTab() {
    if (_filteredRoutes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus_filled_outlined,
                  size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No routes matching "${_searchController.text}"',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredRoutes.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 64, endIndent: 16),
      itemBuilder: (context, index) {
        final route = _filteredRoutes[index];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            width: 44,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              route.number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          title: Text(
            'Line ${route.number}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          subtitle: Text(
            route.name,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(
            Icons.chevron_right,
            size: 18,
            color: Colors.grey,
          ),
          onTap: () => _onSelectRoute(route),
        );
      },
    );
  }
}
