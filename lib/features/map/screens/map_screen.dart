/// Interactive map screen showing Cardiff Bus stops with delay status.
///
/// Each stop is shown as a colour-coded marker on an OpenStreetMap:
/// - **Green**: On time (delay < 2 min)
/// - **Amber**: Minor delay (2–10 min)
/// - **Red**: Major delay (> 10 min)
///
/// Tapping a marker or a stop card shows a detail sheet with stop info.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../data/models/bus_stop.dart';
import '../providers/map_provider.dart';

/// Cardiff city centre coordinates used as the default map centre.
const LatLng _kCardiffCentre = LatLng(51.4816, -3.1791);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(mapProvider.notifier).loadStops(),
    );
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Stop Map'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _buildErrorView(state.error!)
              : _buildMapView(state),
    );
  }

  Widget _buildMapView(MapState state) {
    final markers = state.stops.map((stop) {
      final status = state.delayStatuses[stop.id] ?? StopDelayStatus.unknown;
      final color = _delayColor(status);

      return Marker(
        point: LatLng(stop.latitude, stop.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showStopDetail(context, stop, status),
          child: Icon(
            Icons.location_on,
            color: color,
            size: 36,
            shadows: const [
              Shadow(
                blurRadius: 10,
                color: Colors.black38,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      );
    }).toList();

    return Column(
      children: [
        // ── OpenStreetMap ──────────────────────────────────────────
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _kCardiffCentre,
                    initialZoom: 13.0,
                    onTap: (_, _) {
                      // Tap on empty map area — no action
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.busalert',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
                // ── Legend overlay ─────────────────────────────────
                const _MapLegend(),
              ],
            ),
          ),
        ),

        // ── Stop List Header ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.directions_bus, size: 18, color: kCardiffBlue),
              const SizedBox(width: 8),
              Text(
                'Bus Stops (${state.stops.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                'Tap a marker for details',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ),
        ),

        // ── Stop Card List ─────────────────────────────────────────
        SizedBox(
          height: 200,
          child: ListView.builder(
            controller: _listScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: state.stops.length,
            itemBuilder: (context, index) {
              final stop = state.stops[index];
              final status =
                  state.delayStatuses[stop.id] ?? StopDelayStatus.unknown;
              return _StopCard(
                stop: stop,
                status: status,
                onTap: () => _showStopDetail(context, stop, status),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showStopDetail(
    BuildContext context,
    BusStop stop,
    StopDelayStatus status,
  ) {
    final color = _delayColor(status);
    final label = _delayLabel(status);

    // Scroll the horizontal list to centre this stop's card
    final index = ref.read(mapProvider).stops.indexOf(stop);
    if (index >= 0 && _listScrollController.hasClients) {
      final cardWidth = 172.0; // card width (160) + margin (12)
      final viewportWidth = _listScrollController.position.viewportDimension;
      final targetOffset = (index * cardWidth) - (viewportWidth / 2) + (cardWidth / 2);
      _listScrollController.animateTo(
        targetOffset.clamp(0.0, _listScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.location_on, color: color, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      stop.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.pin_drop, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text(
                    '${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: kDelayRed),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  Color _delayColor(StopDelayStatus status) => switch (status) {
        StopDelayStatus.onTime => kOnTimeGreen,
        StopDelayStatus.minorDelay => kAmberAccent,
        StopDelayStatus.majorDelay => kDelayRed,
        StopDelayStatus.unknown => Colors.grey,
      };

  String _delayLabel(StopDelayStatus status) => switch (status) {
        StopDelayStatus.onTime => 'On time',
        StopDelayStatus.minorDelay => 'Minor delay',
        StopDelayStatus.majorDelay => 'Major delay',
        StopDelayStatus.unknown => 'Unknown',
      };
}

/// Colour legend overlay shown in the top-right corner of the map.
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(210),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delay',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 6),
            _legendDot(kOnTimeGreen, 'On time'),
            const SizedBox(height: 4),
            _legendDot(kAmberAccent, 'Minor'),
            const SizedBox(height: 4),
            _legendDot(kDelayRed, 'Major'),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}

/// A small card for a bus stop shown in the horizontal list.
class _StopCard extends StatelessWidget {
  final BusStop stop;
  final StopDelayStatus status;
  final VoidCallback onTap;

  const _StopCard({
    required this.stop,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StopDelayStatus.onTime => kOnTimeGreen,
      StopDelayStatus.minorDelay => kAmberAccent,
      StopDelayStatus.majorDelay => kDelayRed,
      StopDelayStatus.unknown => Colors.grey,
    };

    final label = switch (status) {
      StopDelayStatus.onTime => 'On time',
      StopDelayStatus.minorDelay => 'Minor delay',
      StopDelayStatus.majorDelay => 'Major delay',
      StopDelayStatus.unknown => 'Unknown',
    };

    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 160,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stop.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
