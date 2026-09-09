/// Unified Trip Predictor & Journey Planner Card.
///
/// Seamlessly combines:
/// 1. Quick Route filter chips (All Routes, 1, 2, 7, 8, 9, 11, 27, 44, 57, 95, etc.)
/// 2. Origin (From) stop selector with 1-tap GPS location detection
/// 3. Destination (To) stop selector with smart direct & connecting transfer discovery
/// 4. Time selection & instant AI delay prediction
/// 5. 1-tap Live WiFi & GPS ride tracking
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/models/planned_journey.dart';
import '../../timetable/screens/route_timetable_screen.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../../tracking/screens/live_tracking_screen.dart';
import '../../tracking/services/gps_tracker.dart';
import '../providers/journey_planner_provider.dart';
import 'destination_picker_modal.dart';

class UnifiedTripPredictorCard extends ConsumerStatefulWidget {
  final List<BusStop> allStops;
  final ValueChanged<PlannedJourney>? onSelectJourney;
  final ValueChanged<String>? onViewRoute;

  const UnifiedTripPredictorCard({
    super.key,
    required this.allStops,
    this.onSelectJourney,
    this.onViewRoute,
  });

  @override
  ConsumerState<UnifiedTripPredictorCard> createState() =>
      _UnifiedTripPredictorCardState();
}

class _UnifiedTripPredictorCardState
    extends ConsumerState<UnifiedTripPredictorCard> {
  static const List<String> _popularRoutes = [
    '1', '2', '7', '8', '9', '11', '13', '21', '23', '24', '27',
    '28', '30', '35', '44', '45', '49', '50', '52', '54', '57', '58', '95',
  ];

  String? _selectedLineFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (widget.allStops.isNotEmpty) {
        ref.read(journeyPlannerProvider.notifier).initStops(stops: widget.allStops);
      }
    });
  }

  @override
  void didUpdateWidget(covariant UnifiedTripPredictorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allStops != widget.allStops && widget.allStops.isNotEmpty) {
      ref.read(journeyPlannerProvider.notifier).initStops(stops: widget.allStops);
    }
  }

  void _onSelectRouteChip(String? route) {
    setState(() {
      _selectedLineFilter = route;
    });

    ref.read(journeyPlannerProvider.notifier).setRouteFilter(route);

    if (route != null) {
      final stopsForRoute = widget.allStops.where((s) => s.routes.contains(route)).toList();
      if (stopsForRoute.isNotEmpty) {
        final plannerState = ref.read(journeyPlannerProvider);
        if (plannerState.originStop == null || !stopsForRoute.any((s) => s.id == plannerState.originStop!.id)) {
          ref.read(journeyPlannerProvider.notifier).setOriginStop(stopsForRoute.first);
        }
        if (stopsForRoute.length > 1) {
          ref.read(journeyPlannerProvider.notifier).setDestinationStop(stopsForRoute.last);
        }
      }
    }
  }

  Future<void> _startWiFiTracking() async {
    final consented = await GpsTracker.showGpsConsentDialog(context);
    if (!mounted || !consented) return;

    await ref.read(trackingProvider.notifier).startTracking();

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LiveTrackingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plannerState = ref.watch(journeyPlannerProvider);
    final now = DateTime.now();

    final originSubtitle = plannerState.isGpsDetected &&
            plannerState.walkingDistanceToOrigin != null
        ? (plannerState.walkingDistanceToOrigin! < 2500
            ? '📍 Nearest GPS Stop • ${plannerState.walkingDistanceToOrigin!.toStringAsFixed(0)}m walk'
            : '📍 Nearest Cardiff Transit Stop')
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kCardiffBlue.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: kCardiffBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip Predictor & Journey Planner',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                    Text(
                      'Choose route or stops for AI delay predictions & live tracking',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Quick Bus Line Chips ────────────────────────────────
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('All Routes'),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _selectedLineFilter == null ? Colors.white : const Color(0xFF334155),
                    ),
                    selected: _selectedLineFilter == null,
                    selectedColor: kCardiffBlue,
                    backgroundColor: const Color(0xFFF1F5F9),
                    showCheckmark: false,
                    onSelected: (_) => _onSelectRouteChip(null),
                  ),
                ),
                ..._popularRoutes.map((routeNum) {
                  final isSelected = _selectedLineFilter == routeNum;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('Line $routeNum'),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                      selected: isSelected,
                      selectedColor: kCardiffBlue,
                      backgroundColor: const Color(0xFFF1F5F9),
                      showCheckmark: false,
                      onSelected: (_) => _onSelectRouteChip(isSelected ? null : routeNum),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Origin & Destination Form ───────────────────────────
          Stack(
            alignment: Alignment.centerRight,
            children: [
              Column(
                children: [
                  // Origin Stop
                  _buildStopTile(
                    label: 'From (Departure Stop)',
                    icon: Icons.my_location,
                    iconColor: kOnTimeGreen,
                    stopName: plannerState.originStop?.name ?? 'Tap to choose departure stop',
                    subtitle: originSubtitle,
                    trailingButton: FilledButton.tonalIcon(
                      onPressed: plannerState.isLoading
                          ? null
                          : () => ref
                              .read(journeyPlannerProvider.notifier)
                              .detectCurrentLocationAsOrigin(),
                      icon: const Icon(Icons.gps_fixed, size: 14),
                      label: const Text('GPS'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 30),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                    ),
                    onTap: () async {
                      final stopsToPick = _selectedLineFilter != null
                          ? widget.allStops.where((s) => s.routes.contains(_selectedLineFilter)).toList()
                          : widget.allStops;

                      final chosen = await showDestinationPicker(
                        context,
                        stops: stopsToPick.isNotEmpty ? stopsToPick : widget.allStops,
                        selectedStop: plannerState.originStop,
                        title: 'Choose Departure Stop',
                      );
                      if (chosen != null) {
                        ref.read(journeyPlannerProvider.notifier).setOriginStop(chosen);
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // Destination Stop
                  _buildStopTile(
                    label: 'To (Destination Stop)',
                    icon: Icons.flag_rounded,
                    iconColor: kDelayRed,
                    stopName: plannerState.destinationStop?.name ?? 'Where are you going? (Tap to search)',
                    subtitle: plannerState.destinationStop != null ? 'Tap to change destination' : null,
                    onTap: () async {
                      final stopsToPick = _selectedLineFilter != null
                          ? widget.allStops.where((s) => s.routes.contains(_selectedLineFilter)).toList()
                          : widget.allStops;

                      final chosen = await showDestinationPicker(
                        context,
                        stops: stopsToPick.isNotEmpty ? stopsToPick : widget.allStops,
                        selectedStop: plannerState.destinationStop,
                        title: 'Choose Destination Stop',
                      );
                      if (chosen != null) {
                        ref.read(journeyPlannerProvider.notifier).setDestinationStop(chosen);
                      }
                    },
                  ),
                ],
              ),

              // Swap Button
              Positioned(
                right: 12,
                child: FloatingActionButton.small(
                  heroTag: 'unified_swap_fab',
                  onPressed: () => ref.read(journeyPlannerProvider.notifier).swapStops(),
                  backgroundColor: Colors.white,
                  foregroundColor: kCardiffBlue,
                  elevation: 2,
                  shape: const CircleBorder(side: BorderSide(color: Colors.black12)),
                  child: const Icon(Icons.swap_vert, size: 18),
                ),
              ),
            ],
          ),

          // ── Loading Indicator ───────────────────────────────────
          if (plannerState.isLoading) ...[
            const SizedBox(height: 20),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Calculating routes & live delays...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Journeys Results Section ────────────────────────────
          if (plannerState.originStop != null && !plannerState.isLoading) ...[
            const SizedBox(height: 14),

            if (plannerState.destinationStop != null && plannerState.journeys.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Routes (${plannerState.journeys.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _startWiFiTracking,
                    icon: const Icon(Icons.wifi_tethering, size: 14),
                    label: const Text('Live WiFi Track'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: plannerState.journeys.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final journey = plannerState.journeys[index];
                  return _buildJourneyCard(
                    journey: journey,
                    now: now,
                    onSelect: () {
                      if (widget.onSelectJourney != null) {
                        widget.onSelectJourney!(journey);
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RouteTimetableScreen(
                              routeNumber: journey.routeNumber.split(' ').first,
                              stop: plannerState.originStop!,
                              initialTime: journey.departureTime,
                            ),
                          ),
                        );
                      }
                    },
                    onViewRoute: widget.onViewRoute != null
                        ? () => widget.onViewRoute!(journey.routeNumber.split(' ').first)
                        : null,
                    onWiFiTrack: _startWiFiTracking,
                  );
                },
              ),
            ] else if (plannerState.destinationStop != null && plannerState.journeys.isEmpty) ...[
              // Smart Alternative: Suggest Direct Lines from Origin
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_bus_filled, size: 18, color: kCardiffBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Direct Lines passing ${plannerState.originStop!.name}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plannerState.originStop!.routes.isNotEmpty
                          ? 'This stop connects to Lines: ${plannerState.originStop!.routes.join(', ')}. Tap any line below to check departures:'
                          : 'Check upcoming departures from this stop below:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: plannerState.originStop!.routes.map((r) {
                        return ActionChip(
                          avatar: const Icon(Icons.directions_bus, size: 14, color: kCardiffBlue),
                          label: Text('Line $r Timetable'),
                          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RouteTimetableScreen(
                                  routeNumber: r,
                                  stop: plannerState.originStop!,
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Dual Global Buttons: Full Timetable & WiFi Live Track ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: plannerState.originStop != null
                      ? () {
                          final r = _selectedLineFilter ??
                              (plannerState.originStop!.routes.isNotEmpty
                                  ? plannerState.originStop!.routes.first
                                  : '27');
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RouteTimetableScreen(
                                routeNumber: r,
                                stop: plannerState.originStop!,
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: const Text('View Timetable'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kCardiffBlue,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _startWiFiTracking,
                  icon: const Icon(Icons.wifi_tethering, size: 16),
                  label: const Text('📶 WiFi Live Track'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStopTile({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String stopName,
    String? subtitle,
    Widget? trailingButton,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stopName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.teal[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingButton != null) ...[
              const SizedBox(width: 8),
              trailingButton,
            ] else ...[
              const Icon(Icons.search, size: 18, color: Colors.grey),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyCard({
    required PlannedJourney journey,
    required DateTime now,
    required VoidCallback onSelect,
    VoidCallback? onViewRoute,
    required VoidCallback onWiFiTrack,
  }) {
    final isTransfer = journey.routeNumber.contains('➔');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTransfer ? Colors.purple.shade200 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Route number badge & countdown
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isTransfer ? Colors.purple.shade700 : kCardiffBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isTransfer ? journey.routeNumber : 'Line ${journey.routeNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  journey.headsign,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: journey.statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: journey.statusColor.withAlpha(60), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: journey.statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      journey.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: journey.statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Time & Duration
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Departs ${journey.departureTime} (${journey.departureCountdown(now)})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Icon(Icons.timer_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${journey.durationMinutes} min (${journey.stopsCount} stops)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onViewRoute != null)
                TextButton.icon(
                  onPressed: onViewRoute,
                  icon: const Icon(Icons.map_outlined, size: 14),
                  label: const Text('Map'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: onWiFiTrack,
                icon: const Icon(Icons.wifi_tethering, size: 14),
                label: const Text('WiFi Track'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: onSelect,
                icon: const Icon(Icons.auto_graph_rounded, size: 14),
                label: const Text('Predict & Details'),
                style: FilledButton.styleFrom(
                  backgroundColor: kCardiffBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
