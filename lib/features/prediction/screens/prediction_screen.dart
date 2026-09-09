/// Dedicated Timetables & Delay Prediction Hub.
///
/// Provides rapid access to all Cardiff Bus line timetables, stop departure tables,
/// live delay predictions, and pinned favorite routes.
/// Differentiates transit Lines (scheduled routes) from Buses (moving vehicles) with dedicated icons
/// in a single unified, mixed directory list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/models/bods_vehicle.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/repositories/gtfs_repository.dart';
import '../../../data/services/stop_service.dart';
import '../../favorites/widgets/pinned_locations_widget.dart';
import '../../map/providers/live_buses_provider.dart';
import '../../timetable/screens/route_timetable_screen.dart';

final StopService _stopService = StopService();

class PredictionScreen extends ConsumerStatefulWidget {
  const PredictionScreen({super.key});

  @override
  ConsumerState<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends ConsumerState<PredictionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<BusStop> _allStops = [];
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _isLoading = false;

  static const List<Map<String, String>> _allCardiffRoutes = [
    {'route': '1', 'name': 'City Centre – Tremorfa – Cardiff Bay', 'cat': 'city,bay'},
    {'route': '1A', 'name': 'City Centre – Ocean Way – Cardiff Bay', 'cat': 'city,bay'},
    {'route': '2', 'name': 'City Centre – Grangetown – Cardiff Bay', 'cat': 'city,bay'},
    {'route': '2A', 'name': 'City Centre – Ocean Way – Grangetown', 'cat': 'city,bay'},
    {'route': '3', 'name': 'City Centre – Wentloog Business Park', 'cat': 'city'},
    {'route': '4', 'name': 'City Centre – Leckwith – Cardiff City Stadium', 'cat': 'city'},
    {'route': '6', 'name': 'Cardiff Bay City Link (baycar)', 'cat': 'bay'},
    {'route': '7', 'name': 'Cardiff Central – Cardiff Bay via Penarth Rd', 'cat': 'bay'},
    {'route': '8', 'name': 'Cardiff Central – Grangetown', 'cat': 'city'},
    {'route': '9', 'name': 'Heath Hospital – City Centre – Sports Village', 'cat': 'hospital,bay'},
    {'route': '11', 'name': 'Cardiff Central – Tremorfa – Pengam Green', 'cat': 'city'},
    {'route': '13', 'name': 'Cardiff Central – Canton – Drope / Ely', 'cat': 'city'},
    {'route': '14', 'name': 'Cardiff Central – Heath Hospital Express', 'cat': 'hospital'},
    {'route': '17', 'name': 'Cardiff Central – Canton – Caerau', 'cat': 'city'},
    {'route': '18', 'name': 'Cardiff Central – Canton – Ely (Circular)', 'cat': 'city'},
    {'route': '21', 'name': 'Cardiff Central – Rhiwbina (Circular)', 'cat': 'city'},
    {'route': '23', 'name': 'Cardiff Central – Whitchurch (Circular)', 'cat': 'city'},
    {'route': '24', 'name': 'Cardiff Central – Llandaff – Whitchurch', 'cat': 'city'},
    {'route': '25', 'name': 'Cardiff Central – Whitchurch – Llandaff', 'cat': 'city'},
    {'route': '25A', 'name': 'Cardiff Central – Whitchurch Express', 'cat': 'city'},
    {'route': '27', 'name': 'Cardiff Central – Birchgrove – Thornhill', 'cat': 'city'},
    {'route': '28', 'name': 'Cardiff Central – Roath – Llanishen – Thornhill', 'cat': 'city'},
    {'route': '29', 'name': 'Cardiff Central – Llanishen', 'cat': 'city'},
    {'route': '30', 'name': 'Cardiff Central – Newport via Royal Gwent Hospital', 'cat': 'hospital'},
    {'route': '32', 'name': 'Cardiff Central – St Fagans National Museum of History', 'cat': 'city'},
    {'route': '35', 'name': 'Cardiff Central – Gabalfa', 'cat': 'city'},
    {'route': '44', 'name': 'Cardiff Central – Rumney – St Mellons', 'cat': 'city'},
    {'route': '45', 'name': 'Cardiff Central – Rumney – St Mellons', 'cat': 'city'},
    {'route': '49', 'name': 'Cardiff Central – Llanrumney', 'cat': 'city'},
    {'route': '50', 'name': 'Cardiff Central – Llanrumney via Royal Hotel', 'cat': 'city'},
    {'route': '52', 'name': 'Cardiff Central – Roath – Cardiff Met Cyncoed', 'cat': 'city'},
    {'route': '54', 'name': 'Cardiff Central – Penylan – Heath Hospital', 'cat': 'hospital'},
    {'route': '57', 'name': 'Cardiff Central – Pentwyn – Pontprennau', 'cat': 'city'},
    {'route': '58', 'name': 'Cardiff Central – Pentwyn – Pontprennau', 'cat': 'city'},
    {'route': '61', 'name': 'Cardiff Central – Canton – Pentrebane', 'cat': 'city'},
    {'route': '62', 'name': 'Cardiff Central – Canton – Rhydlafar', 'cat': 'city'},
    {'route': '63', 'name': 'Cardiff Central – Llandaff – Danescourt – Pentyrch', 'cat': 'city'},
    {'route': '64', 'name': 'Cardiff Central – Danescourt – Morganstown', 'cat': 'city'},
    {'route': '86', 'name': 'Cardiff Central – Lisvane – Thornhill', 'cat': 'city'},
    {'route': '91', 'name': 'Cardiff Central – Penarth Pier Express', 'cat': 'vale'},
    {'route': '92', 'name': 'Cardiff Central – Penarth – Sully', 'cat': 'vale'},
    {'route': '92B', 'name': 'Cardiff Central – Penarth Marina', 'cat': 'vale'},
    {'route': '93', 'name': 'Cardiff Central – Penarth – Barry Morrisons', 'cat': 'vale'},
    {'route': '93S', 'name': 'Cardiff Central – Penarth School Link', 'cat': 'vale'},
    {'route': '94', 'name': 'Cardiff Central – Penarth – Sully – Barry', 'cat': 'vale'},
    {'route': '95', 'name': 'Cardiff Central – Llandough Hospital – Barry Island', 'cat': 'vale,hospital'},
    {'route': '96', 'name': 'Cardiff Central – Wenvoe – Barry Hospital', 'cat': 'vale,hospital'},
    {'route': '101', 'name': 'Colchester Avenue – Cardiff East Community', 'cat': 'city'},
    {'route': '102', 'name': 'Colchester Avenue – Llanrumney Community', 'cat': 'city'},
    {'route': '136', 'name': 'Pentyrch – Creigiau – Radyr Link', 'cat': 'city'},
    {'route': '305', 'name': 'Cardiff Central – Dinas Powys Community', 'cat': 'vale'},
    {'route': '604', 'name': 'Ysgol Plasmawr – Grangetown School Service', 'cat': 'city'},
    {'route': '606', 'name': 'Ysgol Plasmawr – Canton School Service', 'cat': 'city'},
    {'route': '608', 'name': 'Cardiff High – Cyncoed School Service', 'cat': 'city'},
    {'route': '609', 'name': 'Fitzalan High – Riverside School Service', 'cat': 'city'},
    {'route': '610', 'name': 'Bishop of Llandaff – Heath School Service', 'cat': 'hospital'},
    {'route': '611', 'name': 'Cardiff Bay – Cathedral School Service', 'cat': 'bay'},
    {'route': '619', 'name': 'Cardiff Central – St Teilo\'s School Service', 'cat': 'city'},
    {'route': 'B1', 'name': 'Barry Island – Barry Morrisons – Highlight Park', 'cat': 'vale'},
    {'route': 'B2', 'name': 'Barry Island – Cwm Talwg – Barry Morrisons', 'cat': 'vale'},
    {'route': 'H59', 'name': 'Heath Hospital Park & Ride – East Park', 'cat': 'hospital'},
    {'route': 'M1', 'name': 'Cardiff Met Llandaff – Plas Gwyn Halls Shuttle', 'cat': 'city'},
    {'route': 'Sky', 'name': 'Cardiff Central – Cardiff Airport Express (Skycar)', 'cat': 'vale'},
    {'route': 'X45', 'name': 'Cardiff Central – St Mellons Express', 'cat': 'city'},
  ];

  @override
  void initState() {
    super.initState();
    _loadStops();
    Future.microtask(() {
      ref.read(liveBusesProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStops() async {
    setState(() => _isLoading = true);
    try {
      final stops = await _stopService.getStops();
      if (mounted) {
        setState(() {
          _allStops = stops;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openRouteDetails(String routeNumber) {
    final gtfsRepo = GtfsRepository();
    final directions =
        gtfsRepo.isLoaded ? gtfsRepo.getRouteDirections(routeNumber) : null;

    final fallbackStop = _allStops.isNotEmpty
        ? _allStops.firstWhere(
            (s) => s.routes.contains(routeNumber),
            orElse: () => _allStops.first,
          )
        : BusStop(
            id: 999999,
            name: 'Cardiff City Centre',
            latitude: 51.4816,
            longitude: -3.1791,
            routes: [routeNumber],
          );

    final originStop = directions?.direction0?.originStop ?? fallbackStop;
    final destinationStop = directions?.direction0?.destinationStop ??
        directions?.direction1?.originStop;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteTimetableScreen(
          routeNumber: routeNumber,
          stop: originStop,
          destinationStop: destinationStop,
          initialDirectionId: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveBusesState = ref.watch(liveBusesProvider);
    final liveVehicles = liveBusesState.vehicles;

    // Index active live buses by route
    final Map<String, List<BodsVehicle>> routeToLiveBuses = {};
    for (final r in _allCardiffRoutes) {
      final rNum = r['route']!;
      final matches = liveVehicles.where((v) => v.matchesRoute(rNum)).toList();
      if (matches.isNotEmpty) {
        routeToLiveBuses[rNum] = matches;
      }
    }
    final int routesWithLiveBusesCount = routeToLiveBuses.length;

    // Filter lines based on category & search query
    final filteredRoutes = _allCardiffRoutes.where((r) {
      final rNum = r['route']!;
      if (_selectedCategory == 'active_buses') {
        if (!routeToLiveBuses.containsKey(rNum)) return false;
      } else if (_selectedCategory != 'all') {
        final cat = r['cat'] ?? '';
        if (!cat.contains(_selectedCategory)) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return rNum.toLowerCase().contains(q) ||
            r['name']!.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Hero Hub Header ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kCardiffBlue.withAlpha(80),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.table_chart_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Timetables & Live Predictions',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Official Cardiff Bus tables • ML delay forecast',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Fast Route Quick-Launch Bar
                        const Text(
                          'QUICK SELECT TIMETABLE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              '9', '11', '21', '27', '30', '44', '57', '95',
                            ].map((rt) {
                              final hasLive = routeToLiveBuses.containsKey(rt);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  backgroundColor: const Color(0xFF334155),
                                  side: BorderSide.none,
                                  label: Text(
                                    'Line $rt',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  avatar: Icon(
                                    hasLive
                                        ? Icons.directions_bus_rounded
                                        : Icons.alt_route_rounded,
                                    size: 14,
                                    color: hasLive
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFF60A5FA),
                                  ),
                                  onPressed: () => _openRouteDetails(rt),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 2. Pinned Favorite Stops ─────────────────────────
                  PinnedLocationsWidget(
                    onSelectStop: (stop) {
                      final route =
                          stop.routes.isNotEmpty ? stop.routes.first : '27';
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RouteTimetableScreen(
                            routeNumber: route,
                            stop: stop,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── 3. Visual Differentiation Legend ─────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.alt_route_rounded,
                                    size: 14, color: Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Line (Route)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      'Scheduled route path',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                            width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                    Icons.directions_bus_rounded,
                                    size: 14,
                                    color: Color(0xFF16A34A)),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bus (Vehicle)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      'Live moving vehicle',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 4. Section Header Info ──────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cardiff Bus Line Timetables',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '${filteredRoutes.length} lines',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap any route to view its full timetable table, hourly schedule matrix, and live delay predictions.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),

                  // ── 5. Search Filter ────────────────────────────────
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search line number or destination...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: kCardiffBlue),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: kCardiffBlue, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── 6. Category Filter Chips ─────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip('All Lines', 'all',
                            icon: Icons.alt_route_rounded),
                        const SizedBox(width: 8),
                        _buildCategoryChip(
                          'Active Buses ($routesWithLiveBusesCount)',
                          'active_buses',
                          icon: Icons.directions_bus_rounded,
                          badgeColor: const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        _buildCategoryChip('City Centre', 'city'),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Cardiff Bay', 'bay'),
                        const SizedBox(width: 8),
                        _buildCategoryChip(
                            'Hospitals & Express', 'hospital'),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Vale & Barry', 'vale'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 7. Mixed Routes Directory List ───────────────────
                  if (filteredRoutes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text(
                          'No bus lines matching "$_searchQuery"',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredRoutes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = filteredRoutes[index];
                        final routeNum = item['route']!;
                        final routeName = item['name']!;
                        final liveBuses = routeToLiveBuses[routeNum] ?? const [];

                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _openRouteDetails(routeNum),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(5),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Line (Route) Badge with Line Icon
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: kCardiffBlue,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: kCardiffBlue.withAlpha(40),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.alt_route_rounded,
                                                size: 12, color: Colors.white70),
                                            const SizedBox(width: 3),
                                            Text(
                                              routeNum,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Text(
                                          'LINE',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Route Path & Live Status Pills
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          routeName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Color(0xFF1E293B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            // Line Timetable Schedule Pill
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.table_rows_rounded,
                                                      size: 11, color: Color(0xFF2563EB)),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'Timetable Table',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      color: Color(0xFF1E40AF),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Bus Vehicle Operational Status Pill
                                            if (liveBuses.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDCFCE7),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.directions_bus_rounded,
                                                        size: 11, color: Color(0xFF15803D)),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      '${liveBuses.length} live bus${liveBuses.length > 1 ? 'es' : ''}',
                                                      style: const TextStyle(
                                                        fontSize: 10.5,
                                                        color: Color(0xFF15803D),
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(5),
                                                  border: Border.all(
                                                      color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.directions_bus_outlined,
                                                        size: 11, color: Color(0xFF94A3B8)),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      'Scheduled',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        color: Color(0xFF64748B),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (liveBuses.isNotEmpty) ...[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF16A34A),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  const Icon(Icons.chevron_right_rounded,
                                      size: 20, color: Color(0xFF94A3B8)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryChip(
    String label,
    String categoryKey, {
    IconData? icon,
    Color? badgeColor,
  }) {
    final isSelected = _selectedCategory == categoryKey;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedCategory = categoryKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFCBD5E1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withAlpha(40),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (badgeColor ?? const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
