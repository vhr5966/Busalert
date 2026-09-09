/// Widget displaying pinned/favourite bus stops with real-time delay status badges.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/models/bus_stop.dart';
import '../../map/providers/map_provider.dart' show StopDelayStatus;
import '../providers/favorites_provider.dart';

class PinnedLocationsWidget extends ConsumerWidget {
  final ValueChanged<BusStop>? onSelectStop;

  const PinnedLocationsWidget({
    super.key,
    this.onSelectStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesProvider);

    if (state.favoriteStops.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.push_pin, size: 18, color: kCardiffBlue),
            const SizedBox(width: 8),
            Text(
              'Pinned Locations (${state.favoriteStops.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            if (state.lastRefreshed != null)
              Text(
                'Live delays updated',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
          ],
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: state.favoriteStops.length,
            itemBuilder: (context, index) {
              final stop = state.favoriteStops[index];
              final status = state.delayStatuses[stop.id] ?? StopDelayStatus.unknown;
              final delayMin = state.delayMinutesMap[stop.id];

              final color = switch (status) {
                StopDelayStatus.onTime => kOnTimeGreen,
                StopDelayStatus.minorDelay => kAmberAccent,
                StopDelayStatus.majorDelay => kDelayRed,
                StopDelayStatus.unknown => Colors.grey,
              };

              final statusLabel = switch (status) {
                StopDelayStatus.onTime => 'On time',
                StopDelayStatus.minorDelay => delayMin != null ? '+${delayMin.round()}m' : 'Minor delay',
                StopDelayStatus.majorDelay => delayMin != null ? '+${delayMin.round()}m' : 'Major delay',
                StopDelayStatus.unknown => 'No Data',
              };

              return SizedBox(
                width: 175,
                child: Card(
                  margin: const EdgeInsets.only(right: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: color.withAlpha(80), width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelectStop?.call(stop),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ref.read(favoritesProvider.notifier).togglePin(stop);
                                },
                                child: const Icon(Icons.close, size: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          Text(
                            stop.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          Text(
                            stop.routes.isNotEmpty
                                ? 'Routes: ${stop.routes.take(3).join(", ")}'
                                : 'Cardiff Stop',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
