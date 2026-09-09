/// Interactive Journey Planner modal sheet for Home & Explore screen.
///
/// Discovers direct Cardiff Bus routes, intermediate stops, arrival times,
/// AI delay predictions, and provides 1-tap live WiFi ride tracking.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/models/planned_journey.dart';
import '../../prediction/providers/journey_planner_provider.dart';
import '../../prediction/widgets/destination_picker_modal.dart';
import '../../timetable/screens/route_timetable_screen.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../../tracking/screens/live_tracking_screen.dart';
import '../../tracking/services/gps_tracker.dart';

class HomeJourneyPlannerSheet extends ConsumerStatefulWidget {
  final BusStop? prefilledDestination;
  final List<BusStop> allStops;

  const HomeJourneyPlannerSheet({
    super.key,
    this.prefilledDestination,
    required this.allStops,
  });

  @override
  ConsumerState<HomeJourneyPlannerSheet> createState() =>
      _HomeJourneyPlannerSheetState();
}

class _HomeJourneyPlannerSheetState
    extends ConsumerState<HomeJourneyPlannerSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final notifier = ref.read(journeyPlannerProvider.notifier);
      if (widget.allStops.isNotEmpty) {
        notifier.initStops(stops: widget.allStops);
      }

      final plannerState = ref.read(journeyPlannerProvider);
      if (plannerState.originStop == null) {
        await notifier.detectCurrentLocationAsOrigin();
      }

      if (widget.prefilledDestination != null) {
        notifier.setDestinationStop(widget.prefilledDestination!);
        final updatedState = ref.read(journeyPlannerProvider);
        if (updatedState.originStop != null &&
            (updatedState.originStop!.id == widget.prefilledDestination!.id ||
                updatedState.originStop!.name ==
                    widget.prefilledDestination!.name)) {
          // If GPS happens to be at the exact same stop as the selected destination,
          // default departure stop to a major Cardiff transit hub so From and To are not identical
          final alternateOrigin = widget.allStops.where((s) {
            final name = s.name.toLowerCase();
            return (name.contains('central') ||
                    name.contains('westgate') ||
                    name.contains('wood street')) &&
                s.id != widget.prefilledDestination!.id;
          }).firstOrNull;
          if (alternateOrigin != null) {
            notifier.setOriginStop(alternateOrigin);
          }
        }
      }
    });
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
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.alt_route_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Plan Your Journey',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Origin & Destination Form ──
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
                            stopName: plannerState.originStop?.name ??
                                'Detecting current stop...',
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(0, 30),
                                textStyle: const TextStyle(fontSize: 11),
                              ),
                            ),
                            onTap: () async {
                              final chosen = await showDestinationPicker(
                                context,
                                stops: widget.allStops,
                                selectedStop: plannerState.originStop,
                                title: 'Choose Departure Stop',
                              );
                              if (chosen != null) {
                                ref
                                    .read(journeyPlannerProvider.notifier)
                                    .setOriginStop(chosen);
                              }
                            },
                          ),
                          const SizedBox(height: 10),

                          // Destination Stop
                          _buildStopTile(
                            label: 'To (Destination Stop)',
                            icon: Icons.flag_rounded,
                            iconColor: kDelayRed,
                            stopName: plannerState.destinationStop?.name ??
                                'Where are you going? (Tap to choose)',
                            subtitle: plannerState.destinationStop != null
                                ? 'Tap to change destination'
                                : null,
                            onTap: () async {
                              final chosen = await showDestinationPicker(
                                context,
                                stops: widget.allStops,
                                selectedStop: plannerState.destinationStop,
                                title: 'Choose Destination Stop',
                              );
                              if (chosen != null) {
                                ref
                                    .read(journeyPlannerProvider.notifier)
                                    .setDestinationStop(chosen);
                              }
                            },
                          ),
                        ],
                      ),

                      // Swap FAB
                      Positioned(
                        right: 12,
                        child: FloatingActionButton.small(
                          heroTag: 'home_journey_swap_fab',
                          onPressed: () => ref
                              .read(journeyPlannerProvider.notifier)
                              .swapStops(),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2563EB),
                          elevation: 2,
                          shape: const CircleBorder(
                            side: BorderSide(color: Colors.black12),
                          ),
                          child: const Icon(Icons.swap_vert, size: 18),
                        ),
                      ),
                    ],
                  ),

                  // ── Loading ──
                  if (plannerState.isLoading) ...[
                    const SizedBox(height: 24),
                    const Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Finding best routes & predicting delays...',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Results ──
                  if (!plannerState.isLoading &&
                      plannerState.destinationStop != null) ...[
                    const SizedBox(height: 20),
                    if (plannerState.journeys.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Available Routes (${plannerState.journeys.length})',
                            style: const TextStyle(
                              fontSize: 14,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: plannerState.journeys.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final journey = plannerState.journeys[index];
                          return _buildJourneyCard(journey, now);
                        },
                      ),
                    ] else ...[
                      // No direct route banner
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
                            const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Color(0xFF2563EB),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Connecting Cardiff Services',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              plannerState.originStop != null &&
                                      plannerState
                                          .originStop!.routes.isNotEmpty
                                  ? 'Lines passing departure stop (${plannerState.originStop!.name}): ${plannerState.originStop!.routes.join(', ')}.\nTap any line to view timetable & connect:'
                                  : 'Check upcoming departures or try another stop:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (plannerState.originStop?.routes.isNotEmpty == true) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ...?plannerState.originStop?.routes.map((r) {
                                    return ActionChip(
                                      avatar: const Icon(
                                        Icons.directions_bus,
                                        size: 14,
                                        color: Color(0xFF2563EB),
                                      ),
                                      label: Text('Line $r Timetable'),
                                      labelStyle: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => RouteTimetableScreen(
                                              routeNumber: r,
                                              stop: plannerState.originStop!,
                                              destinationStop:
                                                  plannerState.destinationStop,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stopName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
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
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailingButton,
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyCard(PlannedJourney journey, DateTime now) {
    final isDelayed = (journey.delayMinutes ?? 0) > 2;
    final delayText = journey.delayMinutes != null
        ? (isDelayed
            ? '+${journey.delayMinutes!.round()}m delay'
            : 'On time')
        : 'Sched: on time';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Header & Delay Badge
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Bus ${journey.routeNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDelayed
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  delayText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDelayed
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Schedule Times
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                '${journey.departureTime} → ${journey.arrivalTime}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${journey.durationMinutes} min • ${journey.stopsCount} stops)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _startWiFiTracking,
                  icon: const Icon(Icons.wifi_tethering, size: 15),
                  label: const Text('Live Ride Track'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  final plannerState = ref.read(journeyPlannerProvider);
                  if (plannerState.originStop != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RouteTimetableScreen(
                          routeNumber: journey.routeNumber.split(' ').first,
                          stop: plannerState.originStop!,
                          destinationStop: plannerState.destinationStop,
                          initialTime: journey.departureTime,
                        ),
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E293B),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Timetable', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
