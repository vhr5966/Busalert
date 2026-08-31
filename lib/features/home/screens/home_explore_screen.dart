/// Redesigned Home & Explore screen.
///
/// Features:
/// - Hero Header with Greeting and "Where to in Cardiff?" Search Bar.
/// - Live Service Alerts Ticker (with 1-tap modal details).
/// - Smart Nearest Stop & Live Departures card (GPS auto-detection).
/// - Popular Cardiff Bus Lines grid (1-tap access to 9, 11, 21, 27, 30, 44, 95).
/// - Fast action shortcuts to Trip Predictor, Live Transit Map, and My Trips.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/models/bus_stop.dart';
import '../../../data/models/gtfs_model.dart';
import '../../../data/repositories/timetable_repository.dart';
import '../../../data/services/stop_service.dart';
import '../../prediction/widgets/service_alerts_banner.dart';
import '../../timetable/screens/route_timetable_screen.dart';

final StopService _stopService = StopService();
final TimetableRepository _timetableRepo = TimetableRepository();

class HomeExploreScreen extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const HomeExploreScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<HomeExploreScreen> createState() => _HomeExploreScreenState();
}

class _HomeExploreScreenState extends ConsumerState<HomeExploreScreen> {
  BusStop? _nearestStop;
  List<TimetableEntry> _nearbyDepartures = [];
  bool _isLoadingNearest = false;

  static const List<Map<String, String>> _popularRoutes = [
    {'route': '9', 'name': 'Heath Hospital – Sports Village', 'color': '0xFF1E88E5'},
    {'route': '11', 'name': 'Cardiff Central – Pengam Green', 'color': '0xFF43A047'},
    {'route': '21', 'name': 'Cardiff Central – Rhiwbina', 'color': '0xFFE53935'},
    {'route': '27', 'name': 'Cardiff Central – Thornhill', 'color': '0xFF8E24AA'},
    {'route': '30', 'name': 'Cardiff – Newport Express', 'color': '0xFFFB8C00'},
    {'route': '44', 'name': 'Cardiff Central – St Mellons', 'color': '0xFF00ACC1'},
    {'route': '95', 'name': 'Cardiff – Barry Island via Llandough', 'color': '0xFF3949AB'},
  ];

  @override
  void initState() {
    super.initState();
    _detectNearestStopAndDepartures();
  }

  Future<void> _detectNearestStopAndDepartures() async {
    setState(() {
      _isLoadingNearest = true;
    });

    try {
      final stops = await _stopService.getStops();
      if (stops.isEmpty) {
        setState(() => _isLoadingNearest = false);
        return;
      }

      BusStop selected = stops.first;

      // Try GPS acquisition
      try {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }

        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 4),
            ),
          );

          // Find closest stop by distance
          BusStop closest = stops.first;
          double minDistance = double.infinity;
          for (final s in stops) {
            final dist = Geolocator.distanceBetween(
              pos.latitude,
              pos.longitude,
              s.latitude,
              s.longitude,
            );
            if (dist < minDistance) {
              minDistance = dist;
              closest = s;
            }
          }
          selected = closest;
        }
      } catch (_) {
        // Default to first primary Cardiff Central stop
        selected = stops.firstWhere(
          (s) => s.name.contains('Central') || s.name.contains('Queen'),
          orElse: () => stops.first,
        );
      }

      // Fetch live departures for this stop
      final departures = await _timetableRepo.getRealTimeTimetable(
        stop: selected,
      );

      if (mounted) {
        setState(() {
          _nearestStop = selected;
          _nearbyDepartures = departures;
          _isLoadingNearest = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNearest = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: _detectNearestStopAndDepartures,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Hero Welcome Header ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withAlpha(60),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'BusAlert Cardiff',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi, size: 13, color: Colors.greenAccent),
                            SizedBox(width: 5),
                            Text(
                              'Live BODS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search Bar Card (Where to in Cardiff?)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(1); // Go to Predict / Plan tab
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Where to in Cardiff?',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Plan',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── 2. Today's Service Alerts Banner ───────────────────────
            const ServiceAlertsBanner(),

            // ── 3. Smart Nearest Departures Card ────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.near_me_rounded,
                          color: Color(0xFF2563EB),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nearby Departures',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              _nearestStop != null
                                  ? _nearestStop!.name
                                  : 'Detecting closest stop...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        color: Colors.grey[600],
                        onPressed: _detectNearestStopAndDepartures,
                        tooltip: 'Refresh nearby departures',
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  if (_isLoadingNearest)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    )
                  else if (_nearbyDepartures.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No live departures found for this stop right now.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    )
                  else
                    Column(
                      children: _nearbyDepartures.take(3).map((dep) {
                        final minsText = dep.minutesUntilText(now);
                        final delay = dep.delayMinutes ?? 0.0;
                        final isDelayed = delay > 2;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (_nearestStop != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RouteTimetableScreen(
                                      routeNumber: dep.routeNumber,
                                      stop: _nearestStop!,
                                      initialTime: dep.scheduledDeparture,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      dep.routeNumber,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dep.headsign.isNotEmpty ? dep.headsign : 'Cardiff Service',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Color(0xFF1E293B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Sched: ${dep.scheduledDeparture}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        minsText,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isDelayed
                                              ? const Color(0xFFFEF2F2)
                                              : const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isDelayed ? '+${delay.round()}m delay' : 'On time',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isDelayed
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.analytics_outlined, size: 16),
                      label: const Text('View All Live Departures & Predictions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        if (_nearestStop != null && _nearbyDepartures.isNotEmpty) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RouteTimetableScreen(
                                routeNumber: _nearbyDepartures.first.routeNumber,
                                stop: _nearestStop!,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 4. Popular Cardiff Bus Lines ────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Popular Cardiff Lines',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (widget.onNavigateTab != null) {
                      widget.onNavigateTab!(2); // Go to Live Map
                    }
                  },
                  child: const Text('View Live Map', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 94,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _popularRoutes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final item = _popularRoutes[i];
                  final routeColor = Color(int.parse(item['color']!));

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (_nearestStop != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RouteTimetableScreen(
                              routeNumber: item['route']!,
                              stop: _nearestStop!,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(6),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: routeColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Bus ${item['route']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            item['name']!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
