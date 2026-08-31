/// Real-Time Timetable Widget.
///
/// Displays upcoming live & scheduled bus departures for the currently selected
/// stop and bus line with live delay status, countdowns, and auto-refresh.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/models/gtfs_model.dart';
import '../providers/timetable_provider.dart';

class RealTimeTimetableWidget extends ConsumerWidget {
  const RealTimeTimetableWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timetableProvider);
    final now = DateTime.now();

    if (state.stop == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCardiffBlueLight.withAlpha(60),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kCardiffBlue.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(Icons.schedule, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Real-Time Timetable',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select a bus stop above to view real-time departures and live predictions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real-Time Timetable',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        state.stop!.name,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    ref.read(timetableProvider.notifier).refresh();
                  },
                  tooltip: 'Refresh departures',
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (state.lastRefreshed != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Updated ${DateFormat('HH:mm:ss').format(state.lastRefreshed!)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),

            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Departures List ─────────────────────────────────────
            if (state.isLoading && state.departures.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.departures.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (now.hour >= 23 || now.hour < 5) ? Icons.nights_stay : Icons.departure_board,
                      size: 36,
                      color: (now.hour >= 23 || now.hour < 5) ? Colors.indigo : Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (now.hour >= 23 || now.hour < 5)
                          ? 'Service Ended for Today'
                          : 'No Scheduled Departures',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: (now.hour >= 23 || now.hour < 5) ? Colors.indigo : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (now.hour >= 23 || now.hour < 5)
                          ? 'Regular bus services have finished for the night. Service resumes at ~05:30 AM.'
                          : 'No scheduled departures found in the upcoming hours.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.departures.length,
                separatorBuilder: (context, index) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final entry = state.departures[index];
                  return _DepartureTile(entry: entry, now: now);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DepartureTile extends StatelessWidget {
  final TimetableEntry entry;
  final DateTime now;

  const _DepartureTile({
    required this.entry,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final countdown = entry.minutesUntilText(now);

    return Row(
      children: [
        // Route Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: kCardiffBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            entry.routeNumber,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Destination Headsign
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.headsign,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (entry.isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(35),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade700, width: 1.0),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 12, color: Colors.green),
                          SizedBox(width: 2),
                          Text(
                            'LIVE ⚡',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.green,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade400, width: 0.8),
                      ),
                      child: Text(
                        'Scheduled',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  if (entry.isLive &&
                      entry.predictedDeparture != null &&
                      entry.predictedDeparture != entry.scheduledDeparture) ...[
                    Text(
                      entry.scheduledDeparture,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.predictedDeparture} (Live)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                  ] else if (entry.isLive && entry.predictedDeparture != null) ...[
                    Text(
                      '${entry.predictedDeparture} (Live)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Sched: ${entry.scheduledDeparture}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Delay Badge & Countdown
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: entry.statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: entry.statusColor, width: 0.8),
              ),
              child: Text(
                entry.statusLabel,
                style: TextStyle(
                  color: entry.statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              countdown,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
