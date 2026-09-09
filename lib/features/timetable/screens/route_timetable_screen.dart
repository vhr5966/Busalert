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
import '../../../data/repositories/gtfs_repository.dart';
import '../../../data/repositories/prediction_repository.dart';
import '../../../data/repositories/timetable_repository.dart';
import '../../../data/services/route_destination_resolver.dart';
import '../../map/providers/live_buses_provider.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../../tracking/screens/live_tracking_screen.dart';
import '../../tracking/services/gps_tracker.dart';

final TimetableRepository _timetableRepo = TimetableRepository();
final PredictionRepository _predictionRepo = PredictionRepository();

class RouteTimetableScreen extends ConsumerStatefulWidget {
  final String routeNumber;
  final BusStop? stop;
  final BusStop? destinationStop;
  final int? initialDirectionId;
  final String? initialTime;

  const RouteTimetableScreen({
    super.key,
    required this.routeNumber,
    this.stop,
    this.destinationStop,
    this.initialDirectionId,
    this.initialTime,
  });

  @override
  ConsumerState<RouteTimetableScreen> createState() =>
      _RouteTimetableScreenState();
}

class _RouteTimetableScreenState extends ConsumerState<RouteTimetableScreen> {
  RouteDirections? _routeDirections;
  int _activeDirectionId = 0;
  late String _activeRouteNumber;
  late BusStop _originStop;
  late BusStop _destinationStop;
  bool _isInitialized = false;

  List<TimetableEntry> _departures = [];
  List<BusStop> _routeStops = [];
  String? _selectedDepartureTime;
  Prediction? _prediction;
  bool _isLoadingTimetable = true;
  bool _isLoadingPrediction = false;

  DateTime _selectedDate = DateTime.now();
  String _selectedDayCategory = 'today';
  int _selectedMainTab = 0; // 0: Timetable Table, 1: Route Stops
  int _timetableTableMode = 0; // 0: Hourly Matrix Grid, 1: Detailed Tabular List

  @override
  void initState() {
    super.initState();
    _activeRouteNumber = widget.routeNumber;
    _selectedDepartureTime = widget.initialTime;
    _initAndLoadData();
  }

  Future<void> _initAndLoadData() async {
    setState(() => _isLoadingTimetable = true);

    try {
      final gtfsRepo = GtfsRepository();
      if (!gtfsRepo.isLoaded) {
        await gtfsRepo.loadGtfsData();
      }

      final directions = gtfsRepo.getRouteDirections(widget.routeNumber);
      _routeDirections = directions;

      if (!_isInitialized) {
        int dirId = widget.initialDirectionId ?? 0;
        if (widget.initialDirectionId == null && widget.stop != null) {
          final inDir1 = directions.direction1?.stops.any(
            (s) =>
                s.id == widget.stop!.id ||
                s.name == widget.stop!.name ||
                (s.atcoCode.isNotEmpty && s.atcoCode == widget.stop!.atcoCode),
          ) ?? false;
          final inDir0 = directions.direction0?.stops.any(
            (s) =>
                s.id == widget.stop!.id ||
                s.name == widget.stop!.name ||
                (s.atcoCode.isNotEmpty && s.atcoCode == widget.stop!.atcoCode),
          ) ?? false;
          if (inDir1 && !inDir0) {
            dirId = 1;
          }
        }
        _activeDirectionId = dirId;

        final activeDir = directions.getDirection(_activeDirectionId);
        _activeRouteNumber = activeDir?.routeNumber ?? widget.routeNumber;

        _originStop = widget.stop ??
            activeDir?.originStop ??
            BusStop(
              id: 1,
              name: 'Cardiff City Centre',
              latitude: 51.4816,
              longitude: -3.1791,
              routes: [_activeRouteNumber],
            );

        _destinationStop = widget.destinationStop ??
            activeDir?.destinationStop ??
            (activeDir?.originStop != null &&
                    activeDir!.originStop.id != _originStop.id
                ? activeDir.originStop
                : const BusStop(
                    id: 2,
                    name: 'Destination',
                    latitude: 51.4816,
                    longitude: -3.1791,
                    routes: [],
                  ));
        _isInitialized = true;
      }

      await _loadTimetableForActiveDirection();
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTimetable = false);
      }
    }
  }

  Future<void> _loadData() async {
    await _loadTimetableForActiveDirection();
  }

  Future<void> _loadTimetableForActiveDirection() async {
    setState(() => _isLoadingTimetable = true);

    try {
      final gtfsRepo = GtfsRepository();
      if (!gtfsRepo.isLoaded) {
        await gtfsRepo.loadGtfsData();
      }

      final activeDir = _routeDirections?.getDirection(_activeDirectionId);
      final currentRoute = activeDir?.routeNumber ?? _activeRouteNumber;

      // 1. Fetch timetable departures for origin stop, route, direction, and chosen date
      final deps = await _timetableRepo.getRealTimeTimetable(
        stop: _originStop,
        routeNumber: currentRoute,
        directionId: activeDir?.directionId,
        relativeTo: _selectedDate,
        limit: 30,
      );

      // 2. Fetch official ordered stops for this direction from GTFS
      final orderedStops = activeDir?.stops ??
          gtfsRepo.getStopsForRoute(
            currentRoute,
            directionId: activeDir?.directionId,
          );

      final firstTime = deps.isNotEmpty ? deps.first.scheduledDeparture : null;
      final queryTime = _selectedDepartureTime ?? firstTime ?? '12:00';

      if (mounted) {
        setState(() {
          _activeRouteNumber = currentRoute;
          _departures = deps;
          _routeStops = orderedStops.isNotEmpty ? orderedStops : [_originStop];
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

  void _swapDirection() {
    final nextDirectionId = _activeDirectionId == 0 ? 1 : 0;
    final nextDir = _routeDirections?.getDirection(nextDirectionId);

    // Swap origin and destination stops
    final oldOrigin = _originStop;
    final oldDest = _destinationStop;

    BusStop newOrigin = oldDest;
    BusStop newDest = oldOrigin;

    // Look for matching stop in nextDir
    if (nextDir != null && nextDir.stops.isNotEmpty) {
      final matchOrig = nextDir.stops.where(
        (s) =>
            s.id == oldDest.id ||
            s.name == oldDest.name ||
            (s.atcoCode.isNotEmpty && s.atcoCode == oldDest.atcoCode),
      ).firstOrNull;
      if (matchOrig != null) {
        newOrigin = matchOrig;
      } else {
        newOrigin = nextDir.originStop;
      }

      final matchDest = nextDir.stops.where(
        (s) =>
            s.id == oldOrigin.id ||
            s.name == oldOrigin.name ||
            (s.atcoCode.isNotEmpty && s.atcoCode == oldOrigin.atcoCode),
      ).firstOrNull;
      if (matchDest != null) {
        newDest = matchDest;
      } else {
        newDest = nextDir.destinationStop;
      }
    }

    setState(() {
      _activeDirectionId = nextDirectionId;
      _activeRouteNumber = nextDir?.routeNumber ?? _activeRouteNumber;
      _originStop = newOrigin;
      _destinationStop = newDest;
      _selectedDepartureTime = null;
    });

    _loadTimetableForActiveDirection();
  }

  Future<void> _pickStop({required bool isOrigin}) async {
    final activeDir = _routeDirections?.getDirection(_activeDirectionId);
    final availableStops = activeDir?.stops ?? _routeStops;
    if (availableStops.isEmpty) return;

    final selected = await showModalBottomSheet<BusStop>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RouteStopPickerSheet(
        stops: availableStops,
        currentStop: isOrigin ? _originStop : _destinationStop,
        title: isOrigin
            ? 'Select Start Location'
            : 'Select Destination Location',
        routeNumber: _activeRouteNumber,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        if (isOrigin) {
          _originStop = selected;
        } else {
          _destinationStop = selected;
        }
        _selectedDepartureTime = null;
      });
      _loadTimetableForActiveDirection();
    }
  }

  String _activeDestinationName() {
    final activeDir = _routeDirections?.getDirection(_activeDirectionId);
    if (activeDir != null && activeDir.destinationName.isNotEmpty) {
      return activeDir.destinationName;
    }
    return RouteDestinationResolver.resolveDestination(
      routeNumber: _activeRouteNumber,
      stopName: _originStop.name,
      rawHeadsign: _destinationStop.name,
    );
  }

  void _selectDayCategory(String category) {
    final now = DateTime.now();
    DateTime targetDate;

    if (category == 'today') {
      targetDate = now;
    } else if (category == 'weekday') {
      int daysAhead = 0;
      if (now.weekday == 6) {
        daysAhead = 2; // Sat -> Mon
      } else if (now.weekday == 7) {
        daysAhead = 1; // Sun -> Mon
      }
      final isWeekdayToday = now.weekday >= 1 && now.weekday <= 5;
      targetDate = DateTime(
        now.year,
        now.month,
        now.day + daysAhead,
        isWeekdayToday ? now.hour : 0,
        isWeekdayToday ? now.minute : 0,
      );
    } else if (category == 'saturday') {
      final daysAhead = (6 - now.weekday + 7) % 7;
      final isSatToday = now.weekday == 6;
      targetDate = DateTime(
        now.year,
        now.month,
        now.day + daysAhead,
        isSatToday ? now.hour : 0,
        isSatToday ? now.minute : 0,
      );
    } else if (category == 'sunday') {
      final daysAhead = (7 - now.weekday + 7) % 7;
      final isSunToday = now.weekday == 7;
      targetDate = DateTime(
        now.year,
        now.month,
        now.day + daysAhead,
        isSunToday ? now.hour : 0,
        isSunToday ? now.minute : 0,
      );
    } else {
      targetDate = now;
    }

    setState(() {
      _selectedDayCategory = category;
      _selectedDate = targetDate;
      _selectedDepartureTime = null;
    });

    _loadData();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kCardiffBlue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      final isToday = picked.year == now.year &&
          picked.month == now.month &&
          picked.day == now.day;
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          isToday ? now.hour : 0,
          isToday ? now.minute : 0,
        );
        _selectedDayCategory = 'custom';
        _selectedDepartureTime = null;
      });
      _loadData();
    }
  }

  String _formatDayTitle(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName';
  }

  Widget _buildDayFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF334155),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _fetchPrediction(String time) async {
    setState(() => _isLoadingPrediction = true);

    try {
      final pred = await _predictionRepo.getPrediction(
        stopId: _originStop.id.toString(),
        busLine: _activeRouteNumber,
        timeOfDay: time,
        stopName: _originStop.name,
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
    final activeVehicle =
        liveBuses.where((v) => v.matchesRoute(_activeRouteNumber)).firstOrNull;

    final delay = _prediction?.predictedDelayMinutes ?? 0.0;
    final isDelayed = delay > 2.0;
    final statusColor = isDelayed ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Line $_activeRouteNumber Timetable'),
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
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: kCardiffBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alt_route_rounded, size: 16, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                _activeRouteNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _originStop.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Towards ${_activeDestinationName()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kCardiffBlue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: activeVehicle != null
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      activeVehicle != null
                                          ? '1 live bus currently active'
                                          : 'Cardiff Bus Scheduled Service',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: activeVehicle != null
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF64748B),
                                        fontWeight: activeVehicle != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
                                builder: (_) => LiveTrackingScreen(
                                  routeNumber: _activeRouteNumber,
                                  stop: _originStop,
                                ),
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
                  const SizedBox(height: 12),

                  // ── 2. Journey Direction & Stop Selection Card (Point A ⇄ Point B) ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Column(
                          children: [
                            // Start Location (Point A)
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _pickStop(isOrigin: true),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.my_location_rounded,
                                        size: 16,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'From (Start Location)',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            _originStop.name,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 44),
                                  ],
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Divider(height: 10, color: Color(0xFFF1F5F9)),
                            ),
                            // Destination Location (Point B)
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _pickStop(isOrigin: false),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.location_on_rounded,
                                        size: 16,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'To (Destination Location)',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            _destinationStop.name,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 44),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Floating Swap Button
                        Positioned(
                          right: 4,
                          child: Tooltip(
                            message: 'Swap direction',
                            child: Material(
                              color: const Color(0xFFEFF6FF),
                              shape: const CircleBorder(
                                side: BorderSide(color: Color(0xFFBFDBFE), width: 1.5),
                              ),
                              elevation: 2,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _swapDirection,
                                child: const Padding(
                                  padding: EdgeInsets.all(9),
                                  child: Icon(
                                    Icons.swap_vert_rounded,
                                    size: 20,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── 2. Date & Day of Week Selector Bar ───────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(4),
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
                            const Icon(Icons.calendar_today_rounded,
                                size: 14, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(
                              'Schedule: ${_formatDayTitle(_selectedDate)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: _pickCustomDate,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_calendar_rounded,
                                        size: 15, color: Color(0xFF2563EB)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Pick Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildDayFilterChip(
                                label: 'Today',
                                isSelected: _selectedDayCategory == 'today',
                                onTap: () => _selectDayCategory('today'),
                              ),
                              const SizedBox(width: 6),
                              _buildDayFilterChip(
                                label: 'Mon – Fri',
                                isSelected: _selectedDayCategory == 'weekday',
                                onTap: () => _selectDayCategory('weekday'),
                              ),
                              const SizedBox(width: 6),
                              _buildDayFilterChip(
                                label: 'Saturday',
                                isSelected: _selectedDayCategory == 'saturday',
                                onTap: () => _selectDayCategory('saturday'),
                              ),
                              const SizedBox(width: 6),
                              _buildDayFilterChip(
                                label: 'Sunday',
                                isSelected: _selectedDayCategory == 'sunday',
                                onTap: () => _selectDayCategory('sunday'),
                              ),
                              if (_selectedDayCategory == 'custom') ...[
                                const SizedBox(width: 6),
                                _buildDayFilterChip(
                                  label:
                                      '${_selectedDate.day}/${_selectedDate.month}',
                                  isSelected: true,
                                  onTap: _pickCustomDate,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── 3. Live Delay Prediction Hero Card ───────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDelayed
                            ? [const Color(0xFFFEF2F2), Colors.white]
                            : [const Color(0xFFF0FDF4), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withAlpha(50)),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withAlpha(12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
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
                                  isDelayed
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_rounded,
                                  color: statusColor,
                                  size: 18,
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
                                color: statusColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _prediction != null
                                    ? '${_prediction!.confidenceLevel} Confidence'
                                    : 'Calculating',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_isLoadingPrediction)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'SCHEDULED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _selectedDepartureTime ?? '--:--',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const Text(
                                        'Official Timetable',
                                        style: TextStyle(
                                            fontSize: 10, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_forward_rounded,
                                      size: 16, color: Color(0xFF64748B)),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'PREDICTED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _calculatePredictedArrival(
                                          _selectedDepartureTime ?? '12:00',
                                          delay,
                                        ),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: statusColor,
                                        ),
                                      ),
                                      Text(
                                        delay > 0.0
                                            ? '+${delay.toStringAsFixed(1)} min delay'
                                            : 'On Time',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Icon(Icons.touch_app_outlined,
                                size: 12, color: Color(0xFF94A3B8)),
                            SizedBox(width: 4),
                            Text(
                              'Tap any departure slot below to forecast delay',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── 4. Main Navigation Tab Bar (Timetable vs Route Stops) ──
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () => setState(() => _selectedMainTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _selectedMainTab == 0
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _selectedMainTab == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(8),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.table_chart_rounded,
                                    size: 15,
                                    color: _selectedMainTab == 0
                                        ? kCardiffBlue
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Timetable (${_departures.length})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _selectedMainTab == 0
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: _selectedMainTab == 0
                                          ? kCardiffBlue
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () => setState(() => _selectedMainTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _selectedMainTab == 1
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _selectedMainTab == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(8),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.linear_scale_rounded,
                                    size: 15,
                                    color: _selectedMainTab == 1
                                        ? kCardiffBlue
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Route Stops (${_routeStops.length})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _selectedMainTab == 1
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: _selectedMainTab == 1
                                          ? kCardiffBlue
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_selectedMainTab == 0) ...[
                    // Timetable Sub-header with View Mode Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Timetable (${_departures.length} departures)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => setState(() => _timetableTableMode = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _timetableTableMode == 0
                                        ? kCardiffBlue
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.grid_view_rounded,
                                        size: 14,
                                        color: _timetableTableMode == 0
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Grid',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _timetableTableMode == 0
                                              ? Colors.white
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => setState(() => _timetableTableMode = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _timetableTableMode == 1
                                        ? kCardiffBlue
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.view_headline_rounded,
                                        size: 14,
                                        color: _timetableTableMode == 1
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Table',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _timetableTableMode == 1
                                              ? Colors.white
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_timetableTableMode == 0)
                      _buildDepartureTimesGrid(now)
                    else
                      _buildDetailedTabularList(now),
                  ] else ...[
                    _buildRouteStopsList(),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildDepartureTimesGrid(DateTime now) {
    if (_departures.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_busy, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(
              'No departures scheduled for Line $_activeRouteNumber at this stop on this day.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _departures.length,
      itemBuilder: (context, i) {
        final dep = _departures[i];
        final timeStr = dep.scheduledDeparture;
        final isSelected = _selectedDepartureTime == timeStr;
        final minsText = dep.minutesUntilText(now);
        final isUpcoming = !minsText.contains('ago');

        return Material(
          color: isSelected ? kCardiffBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _fetchPrediction(timeStr),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
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
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withAlpha(3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.check, size: 14, color: Colors.white),
                        ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  if (minsText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      minsText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.white.withAlpha(220)
                            : (isUpcoming ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailedTabularList(DateTime now) {
    if (_departures.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          'No departures scheduled for Line $_activeRouteNumber on this day.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: const Color(0xFFF1F5F9),
              child: const Row(
                children: [
                  SizedBox(
                    width: 75,
                    child: Text(
                      'TIME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'DESTINATION & VIA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _departures.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final dep = _departures[idx];
                final isSelected = _selectedDepartureTime == dep.scheduledDeparture;
                final minsText = dep.minutesUntilText(now);
                final destination = RouteDestinationResolver.resolveDestination(
                  routeNumber: _activeRouteNumber,
                  stopName: _originStop.name,
                  rawHeadsign: dep.headsign,
                );

                return Material(
                  color: isSelected ? kCardiffBlue.withAlpha(20) : Colors.transparent,
                  child: InkWell(
                    onTap: () => _fetchPrediction(dep.scheduledDeparture),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 75,
                            child: Row(
                              children: [
                                if (isSelected)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.check, size: 14, color: kCardiffBlue),
                                  ),
                                Text(
                                  dep.scheduledDeparture,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? kCardiffBlue : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kCardiffBlue.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _activeRouteNumber,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: kCardiffBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    destination,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (minsText.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      minsText,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStopsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _routeStops.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 40),
        itemBuilder: (context, idx) {
          final st = _routeStops[idx];
          final isCurrentStop =
              st.id == _originStop.id || st.name == _originStop.name;
          final isDestinationStop =
              st.id == _destinationStop.id || st.name == _destinationStop.name;

          return ListTile(
            leading: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCurrentStop
                    ? const Color(0xFF16A34A)
                    : (isDestinationStop
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFE2E8F0)),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCurrentStop
                    ? const Icon(Icons.my_location,
                        size: 14, color: Colors.white)
                    : (isDestinationStop
                        ? const Icon(Icons.location_on,
                            size: 14, color: Colors.white)
                        : const Icon(Icons.place_rounded,
                            size: 13, color: Color(0xFF64748B))),
              ),
            ),
            title: Text(
              st.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCurrentStop || isDestinationStop
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: isCurrentStop
                    ? const Color(0xFF16A34A)
                    : (isDestinationStop
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0F172A)),
              ),
            ),
            subtitle: isCurrentStop
                ? const Text(
                    'Boarding Stop (Start Location)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : (isDestinationStop
                    ? const Text(
                        'Destination Stop',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null),
            trailing:
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            onTap: () {
              setState(() {
                _originStop = st;
                _selectedDepartureTime = null;
                _selectedMainTab = 0; // Switch to Timetable Departures view
              });
              _loadTimetableForActiveDirection();
            },
          );
        },
      ),
    );
  }
}

/// Bottom sheet modal to search and pick any stop along the active route direction.
class _RouteStopPickerSheet extends StatefulWidget {
  final List<BusStop> stops;
  final BusStop currentStop;
  final String title;
  final String routeNumber;

  const _RouteStopPickerSheet({
    required this.stops,
    required this.currentStop,
    required this.title,
    required this.routeNumber,
  });

  @override
  State<_RouteStopPickerSheet> createState() => _RouteStopPickerSheetState();
}

class _RouteStopPickerSheetState extends State<_RouteStopPickerSheet> {
  String _query = '';
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.stops.where((s) {
      if (_query.isEmpty) return true;
      return s.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _controller,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'Search stops on Line ${widget.routeNumber}...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: Color(0xFF2563EB)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
              itemBuilder: (context, index) {
                final stop = filtered[index];
                final isSelected = stop.id == widget.currentStop.id ||
                    stop.name == widget.currentStop.name;
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    stop.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF2563EB), size: 20)
                      : null,
                  onTap: () => Navigator.of(context).pop(stop),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
