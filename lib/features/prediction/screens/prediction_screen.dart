/// Modern Trip Predictor & Route Explorer Screen.
///
/// Features:
/// - Quick Origin → Destination Transit Search.
/// - Cardiff Bus Line Grid with live filtering.
/// - 1-tap navigation directly into dedicated RouteTimetableScreen.
/// - Pinned favorite stops for rapid predictions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/models/planned_journey.dart';
import '../../../data/services/stop_service.dart';
import '../../favorites/widgets/pinned_locations_widget.dart';
import '../../timetable/screens/route_timetable_screen.dart';
import '../widgets/unified_trip_predictor_card.dart';

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
  bool _isLoading = false;

  static const List<Map<String, String>> _allCardiffRoutes = [
    {'route': '1', 'name': 'City Centre – Tremorfa – Cardiff Bay'},
    {'route': '2', 'name': 'City Centre – Grangetown – Cardiff Bay'},
    {'route': '7', 'name': 'Cardiff Central – Cardiff Bay via Penarth Rd'},
    {'route': '8', 'name': 'Cardiff Central – Grangetown'},
    {'route': '9', 'name': 'Heath Hospital – City Centre – Sports Village'},
    {'route': '11', 'name': 'Cardiff Central – Tremorfa – Pengam Green'},
    {'route': '13', 'name': 'Cardiff Central – Canton – Ely'},
    {'route': '21', 'name': 'Cardiff Central – Rhiwbina (Circular)'},
    {'route': '23', 'name': 'Cardiff Central – Whitchurch (Circular)'},
    {'route': '24', 'name': 'Cardiff Central – Llandaff – Whitchurch'},
    {'route': '27', 'name': 'Cardiff Central – Birchgrove – Thornhill'},
    {'route': '28', 'name': 'Cardiff Central – Roath – Thornhill'},
    {'route': '30', 'name': 'Cardiff – Newport Express Service'},
    {'route': '35', 'name': 'Cardiff Central – Gabalfa'},
    {'route': '44', 'name': 'Cardiff Central – Rumney – St Mellons'},
    {'route': '45', 'name': 'Cardiff Central – Rumney – St Mellons'},
    {'route': '49', 'name': 'Cardiff Central – Llanrumney'},
    {'route': '50', 'name': 'Cardiff Central – Llanrumney'},
    {'route': '52', 'name': 'Cardiff Central – Roath – Cyncoed'},
    {'route': '54', 'name': 'Cardiff Central – Penylan – Cyncoed'},
    {'route': '57', 'name': 'Cardiff Central – Pentwyn – Pontprennau'},
    {'route': '58', 'name': 'Cardiff Central – Pentwyn – Pontprennau'},
    {'route': '61', 'name': 'Cardiff Central – Canton – Pentrebane'},
    {'route': '62', 'name': 'Cardiff Central – Canton – Rhydypenau'},
    {'route': '63', 'name': 'Cardiff Central – Llandaff – Danescourt'},
    {'route': '92', 'name': 'Cardiff Central – Penarth – Sully'},
    {'route': '94', 'name': 'Cardiff Central – Penarth – Barry'},
    {'route': '95', 'name': 'Cardiff Central – Llandough – Barry Island'},
    {'route': '96', 'name': 'Cardiff Central – Wenvoe – Barry'},
    {'route': 'X45', 'name': 'Cardiff Central – St Mellons Express'},
  ];

  @override
  void initState() {
    super.initState();
    _loadStops();
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
    if (_allStops.isEmpty) return;

    // Pick first stop serving this route
    final stop = _allStops.firstWhere(
      (s) => s.routes.contains(routeNumber),
      orElse: () => _allStops.first,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteTimetableScreen(
          routeNumber: routeNumber,
          stop: stop,
        ),
      ),
    );
  }

  void _onSelectPlannedJourney(PlannedJourney journey) {
    if (_allStops.isEmpty) return;

    final origin = _allStops.firstWhere(
      (s) => s.id.toString() == journey.originStopId || s.name == journey.originStopName,
      orElse: () => _allStops.first,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteTimetableScreen(
          routeNumber: journey.routeNumber,
          stop: origin,
          initialTime: journey.departureTime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRoutes = _searchQuery.isEmpty
        ? _allCardiffRoutes
        : _allCardiffRoutes.where((r) {
            final q = _searchQuery.toLowerCase();
            return r['route']!.toLowerCase().contains(q) ||
                r['name']!.toLowerCase().contains(q);
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
                  // ── 1. Unified Trip Predictor & Journey Planner Card ──
                  UnifiedTripPredictorCard(
                    allStops: _allStops,
                    onSelectJourney: _onSelectPlannedJourney,
                    onViewRoute: _openRouteDetails,
                  ),
                  const SizedBox(height: 14),

                  // ── 2. Pinned Favorite Stops ─────────────────────────
                  PinnedLocationsWidget(
                    onSelectStop: (stop) {
                      final route = stop.routes.isNotEmpty ? stop.routes.first : '27';
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

                  // ── 3. Search & Cardiff Bus Lines Header ─────────────
                  const Text(
                    'Cardiff Bus Lines & Predictions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap any route to check live timetables, delay predictions, and stop sequence.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),

                  // Search Filter
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search line number or destination...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, size: 20, color: kCardiffBlue),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        borderSide: const BorderSide(color: kCardiffBlue, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 4. Search Results: Matching Stops (if searching) ──
                  if (_searchQuery.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final q = _searchQuery.toLowerCase();
                        final matchingStops = _allStops
                            .where((s) => s.name.toLowerCase().contains(q) || s.routes.any((r) => r.toLowerCase().contains(q)))
                            .take(6)
                            .toList();

                        if (matchingStops.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Matching Bus Stops',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...matchingStops.map((stop) {
                              final route = stop.routes.isNotEmpty ? stop.routes.first : '27';
                              return Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => RouteTimetableScreen(
                                          routeNumber: route,
                                          stop: stop,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: kCardiffBlue.withAlpha(20),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.location_on, color: kCardiffBlue, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stop.name,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Lines: ${stop.routes.take(4).join(', ')}',
                                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            const Text(
                              'Matching Bus Lines',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ],

                  // ── 5. Routes List (On-Click Cards) ──────────────────
                  if (filteredRoutes.isEmpty && _searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
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

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
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
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _openRouteDetails(routeNum),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: kCardiffBlue,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      routeNum,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
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
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Live Scheduled Timetable • Delay AI',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF16A34A),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
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
}
