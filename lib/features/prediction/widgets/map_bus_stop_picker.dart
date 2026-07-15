/// Interactive map widget for selecting a bus stop visually.
///
/// Shows all available stops as markers on an OpenStreetMap powered map
/// centred on Cardiff city centre. Tapping a marker selects that stop.
/// The selected stop is highlighted with a different colour marker and
/// shown in a card below the map.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../data/models/bus_stop.dart';

/// Cardiff city centre coordinates used as the default map centre.
const LatLng kCardiffCentre = LatLng(51.4816, -3.1791);

/// Initial zoom level that shows the full Cardiff bus stop network.
const double kInitialZoom = 13.0;

/// Callback invoked when the user taps a bus stop marker.
typedef StopSelectedCallback = void Function(BusStop stop);

class MapBusStopPicker extends StatelessWidget {
  /// All bus stops available to display on the map.
  final List<BusStop> stops;

  /// The currently selected bus stop, if any.
  final BusStop? selectedStop;

  /// Called when the user taps a stop marker.
  final StopSelectedCallback onStopSelected;

  const MapBusStopPicker({
    super.key,
    required this.stops,
    required this.selectedStop,
    required this.onStopSelected,
  });

  @override
  Widget build(BuildContext context) {
    final markers = stops.map((stop) {
      final isSelected = stop.id == selectedStop?.id;
      return Marker(
        point: LatLng(stop.latitude, stop.longitude),
        width: isSelected ? 40 : 32,
        height: isSelected ? 40 : 32,
        child: GestureDetector(
          onTap: () => onStopSelected(stop),
          child: Icon(
            isSelected ? Icons.directions_bus : Icons.location_on,
            color: isSelected ? kCardiffBlue : Colors.red,
            size: isSelected ? 36 : 28,
            shadows: const [
              Shadow(
                blurRadius: 8,
                color: Colors.black26,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Map ────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 280,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: kCardiffCentre,
                initialZoom: kInitialZoom,
                onTap: (_, _) {
                  // Tap on empty map area — no action (deselect not supported)
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
          ),
        ),
        const SizedBox(height: 12),

        // ── Selected Stop Indicator ─────────────────────────────────
        if (selectedStop != null)
          Card(
            color: kCardiffBlue.withAlpha(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kCardiffBlue.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      color: kCardiffBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Stop',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedStop!.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle,
                    color: kOnTimeGreen,
                    size: 20,
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app,
                  size: 18,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap a bus stop on the map',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
