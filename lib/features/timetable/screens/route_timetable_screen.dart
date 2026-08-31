/// Dedicated Route & Timetable screen with live delay prediction.
///
/// Opened on-click whenever a user taps a bus route, departure card, or stop.
///
/// Features:
/// - Hero Header with Route Badge, direction, and live tracking status.
/// - Live Prediction Card comparing Scheduled Time vs Predicted Arrival.
/// - Interactive Departures Schedule (1-tap to predict delay for any upcoming bus).
/// - Stop sequence timeline for the selected route.
/// - Actions: "Track Live on Map" and "Record Journey".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/models/gtfs_model.dart';
import '../../../data/models/prediction.dart';
import '../../../data/repositories/prediction_repository.dart';
import '../../../data/repositories/timetable_repository.dart';
import '../../../data/services/stop_service.dart';
import '../../map/providers/live_buses_provider.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../../tracking/screens/live_tracking_screen.dart';
import '../../tracking/services/gps_tracker.dart';

final TimetableRepository _timetableRepo = TimetableRepository();
final PredictionRepository _predictionRepo = PredictionRepository();
final StopService _stopService = StopService();

class RouteTimetableScreen extends ConsumerStatefulWidget {
  final String routeNumber;
  final BusStop stop;
  final String? initialTime;

  const RouteTimetableScreen({
    super.key,
    required this.routeNumber,
    required this.stop,
    this.initialTime,
  });

  @override
  ConsumerState<RouteTimetableScreen> createState() =>
      _RouteTimetableScreenState();
}

class _RouteTimetableScreenState extends ConsumerState<RouteTimetableScreen> {
  List<TimetableEntry> _departures = [];
  List<BusStop> _routeStops = [];
  String? _selectedDepartureTime;
  Prediction? _prediction;
  bool _isLoadingTimetable = true;
  bool _isLoadingPrediction = false;

  @override
  void initState() {
    super.initState();
    _selectedDepartureTime = widget.initialTime;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingTimetable = true);

    try {
      // 1. Fetch timetable departures for this stop and route
      final deps = await _timetableRepo.getRealTimeTimetable(
        stop: widget.stop,
        routeNumber: widget.routeNumber,
      );

      // 2. Fetch all stops on this route
      final allStops = await _stopService.getStops();
      final filteredStops = allStops
          .where((s) => s.routes.contains(widget.routeNumber))
          .toList();

      final firstTime = deps.isNotEmpty ? deps.first.scheduledDeparture : null;
      final queryTime = _selectedDepartureTime ?? firstTime ?? '12:00';

      if (mounted) {
        setState(() {
          _departures = deps;
          _routeStops = filteredStops.isNotEmpty ? filteredStops : [widget.stop];
          _selectedDepartureTime = queryTime;
          _isLoadingTimetable = false;
        });
      }

      await _fetchPrediction(queryTime);
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTimetable = false);
      }
    }
  }

  Future<void> _fetchPrediction(String time) async {
    setState(() => _isLoadingPrediction = true);

    try {
      final pred = await _predictionRepo.getPrediction(
        stopId: widget.stop.id.toString(),
        busLine: widget.routeNumber,
        timeOfDay: time,
        stopName: widget.stop.name,
      );

      if (mounted) {
        setState(() {
          _prediction = pred;
          _selectedDepartureTime = time;
          _isLoadingPrediction = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPrediction = false);
      }
    }
  }

  String _calculatePredictedArrival(String scheduledTime, double delayMinutes) {
    try {
      final parts = scheduledTime.split(':');
      if (parts.length == 2) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final now = DateTime.now();
        final base = DateTime(now.year, now.month, now.day, hours, minutes);
        final adjusted = base.add(Duration(minutes: delayMinutes.round()));
        return '${adjusted.hour.toString().padLeft(2, '0')}:${adjusted.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return scheduledTime;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final liveBuses = ref.watch(liveBusesProvider).vehicles;
    final activeVehicle = liveBuses.where((v) => v.lineRef == widget.routeNumber).firstOrNull;

    final delay = _prediction?.predictedDelayMinutes ?? 0.0;
    final isDelayed = delay > 2.0;
    final statusColor = isDelayed ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Bus ${widget.routeNumber} Details'),
        elevation: 0,
      ),
      body: _isLoadingTimetable
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Route Summary Header Card ────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(6),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: kCardiffBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.routeNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.stop.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeVehicle != null
                                    ? '1 live bus currently active'
                                    : 'Cardiff Bus Scheduled Service',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: activeVehicle != null
                                      ? const Color(0xFF16A34A)
                                      : Colors.grey[600],
                                  fontWeight: activeVehicle != null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
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
                          icon: const Icon(Icons.wifi_tethering, size: 14),
                          label: const Text('WiFi Track'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 2. Live Delay Prediction Card ────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDelayed
                            ? [const Color(0xFFFEF2F2), Colors.white]
                            : [const Color(0xFFF0FDF4), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: statusColor.withAlpha(60)),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withAlpha(15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isDelayed ? Icons.warning_amber_rounded : Icons.check_circle,
                                  color: statusColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isDelayed ? 'Minor Traffic Delay' : 'Running On Time',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _prediction != null ? '${_prediction!.confidenceLevel} Confidence' : 'Calculating',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (_isLoadingPrediction)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'SCHEDULED',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedDepartureTime ?? '--:--',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      Text(
                                        'Official Timetable',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: statusColor.withAlpha(15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor.withAlpha(80)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PREDICTED',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _calculatePredictedArrival(
                                          _selectedDepartureTime ?? '12:00',
                                          delay,
                                        ),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                      Text(
                                        delay > 0.0
                                            ? '+${delay.toStringAsFixed(1)} min delay'
                                            : 'On Time',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── 3. Upcoming Scheduled Departures (1-Tap Select) ──
                  const Text(
                    'Upcoming Timetable Slots',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_departures.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'No upcoming departures for Line ${widget.routeNumber} at this stop today.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    )
                  else
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _departures.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final dep = _departures[i];
                          final timeStr = dep.scheduledDeparture;
                          final isSelected = _selectedDepartureTime == timeStr;
                          final minsText = dep.minutesUntilText(now);

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _fetchPrediction(timeStr),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? kCardiffBlue : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? kCardiffBlue : const Color(0xFFCBD5E1),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: kCardiffBlue.withAlpha(50),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$timeStr ($minsText)',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),

                  // ── 4. Route Stop Sequence ──────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Route Stops (${_routeStops.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Line ${widget.routeNumber}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _routeStops.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 40),
                      itemBuilder: (context, idx) {
                        final st = _routeStops[idx];
                        final isCurrentStop = st.id == widget.stop.id;

                        return ListTile(
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isCurrentStop ? kCardiffBlue : const Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isCurrentStop
                                  ? const Icon(Icons.my_location, size: 14, color: Colors.white)
                                  : Text(
                                      '${idx + 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            st.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrentStop ? FontWeight.bold : FontWeight.w500,
                              color: isCurrentStop ? kCardiffBlue : const Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: isCurrentStop
                            ? const Text('Your Departure Stop', style: TextStyle(fontSize: 11, color: kCardiffBlue))
                            : null,
                          trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                          onTap: () {
                            // Switch selected stop
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => RouteTimetableScreen(
                                  routeNumber: widget.routeNumber,
                                  stop: st,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
