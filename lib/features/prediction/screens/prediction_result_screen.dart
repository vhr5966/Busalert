/// Detailed prediction result screen.
///
/// Displays the predicted delay with a large, colour-coded indicator,
/// confidence level, number of samples used, and the scheduled timetable.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/models/prediction.dart';

class PredictionResultScreen extends StatelessWidget {
  final Prediction prediction;

  const PredictionResultScreen({super.key, required this.prediction});

  @override
  Widget build(BuildContext context) {
    final delay = prediction.predictedDelayMinutes;
    final color = delayColor(delay);
    final label = delayLabel(delay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prediction Result'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Large Delay Indicator ───────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      delay <= 2
                          ? Icons.check_circle
                          : delay <= 10
                              ? Icons.warning_amber_rounded
                              : Icons.error,
                      size: 64,
                      color: color,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${delay.toStringAsFixed(1)} min delay predicted',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Route Details ───────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Route Details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(),
                    _InfoRow(
                      label: 'Bus Line',
                      value: prediction.busLine,
                    ),
                    _InfoRow(
                      label: 'Stop',
                      value: prediction.stopName,
                    ),
                    _InfoRow(
                      label: 'Time',
                      value: prediction.timeOfDay,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Prediction Details ──────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prediction Details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(),
                    _InfoRow(
                      label: 'Scheduled duration',
                      value:
                          '${prediction.scheduledDurationMinutes.toStringAsFixed(0)} min',
                    ),
                    _InfoRow(
                      label: 'Average actual duration',
                      value:
                          '${prediction.averageActualDurationMinutes.toStringAsFixed(0)} min',
                    ),
                    _InfoRow(
                      label: 'Predicted delay',
                      value:
                          '${prediction.predictedDelayMinutes.toStringAsFixed(1)} min',
                      valueColor: color,
                    ),
                    const Divider(),
                    _InfoRow(
                      label: 'Confidence',
                      value: prediction.confidenceLevel,
                    ),
                    _InfoRow(
                      label: 'Data points',
                      value: '${prediction.sampleSize} historical records',
                    ),
                    if (prediction.sampleSize < 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '⚠ Low confidence: only ${prediction.sampleSize} records '
                          'available. Predictions improve as more users contribute data.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange[700],
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Official Timetable ──────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timetable',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(),
                    // Derive nearby departure times from the queried time.
                    // Cardiff Bus routes typically run at 10–15 minute
                    // headways during the day, longer in the evenings.
                    // We generate ±2 services around the queried time to
                    // give the user a realistic departure board.
                    _TimetableSection(
                      busLine: prediction.busLine,
                      timeOfDay: prediction.timeOfDay,
                      delayMinutes: prediction.predictedDelayMinutes,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generates a realistic departure board from the queried time.
///
/// Cardiff Bus frequencies (approximate, based on public timetables):
/// - Peak hours (07:00–09:00, 16:00–18:00): every 10 minutes
/// - Daytime (09:00–16:00): every 12 minutes
/// - Evening (18:00–22:00): every 20 minutes
/// - Night (22:00–07:00): every 30 minutes
class _TimetableSection extends StatelessWidget {
  final String busLine;
  final String timeOfDay; // "HH:mm"
  final double delayMinutes;

  const _TimetableSection({
    required this.busLine,
    required this.timeOfDay,
    required this.delayMinutes,
  });

  /// Returns the headway in minutes for the given hour of day.
  int _headwayFor(int hour) {
    if ((hour >= 7 && hour < 9) || (hour >= 16 && hour < 18)) return 10;
    if (hour >= 9 && hour < 16) return 12;
    if (hour >= 18 && hour < 22) return 20;
    return 30;
  }

  /// Parses "HH:mm" into a [DateTime] anchored to today's date.
  DateTime _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queried = _parseTime(timeOfDay);
    final headway = _headwayFor(queried.hour);
    final fmt = DateFormat('HH:mm');
    final delayInt = delayMinutes.round();
    final isDelayed = delayMinutes > 2;

    // Build ±2 departures around the queried time.
    final departures = [
      queried.subtract(Duration(minutes: headway * 2)),
      queried.subtract(Duration(minutes: headway)),
      queried,
      queried.add(Duration(minutes: headway)),
      queried.add(Duration(minutes: headway * 2)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.departure_board, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bus $busLine — estimated departures',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              Text(
                'Every $headway min',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        // Column headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              const SizedBox(width: 26),
              SizedBox(
                width: 52,
                child: Text(
                  'Sched.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                'Expected',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Departure rows
        ...departures.map((dep) {
          final isQueried = dep == queried;
          final scheduled = fmt.format(dep);
          final expected = fmt.format(dep.add(Duration(minutes: delayInt)));
          final rowColor = isQueried
              ? delayColor(delayMinutes).withAlpha(18)
              : Colors.transparent;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: rowColor,
              borderRadius: BorderRadius.circular(8),
              border: isQueried
                  ? Border.all(
                      color: delayColor(delayMinutes).withAlpha(70),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.directions_bus,
                  size: 15,
                  color: isQueried
                      ? delayColor(delayMinutes)
                      : Colors.grey[400],
                ),
                const SizedBox(width: 8),
                // Scheduled time
                SizedBox(
                  width: 44,
                  child: Text(
                    scheduled,
                    style: TextStyle(
                      fontWeight: isQueried
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                      color: isQueried ? null : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward,
                    size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                // Expected time
                Text(
                  expected,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isQueried ? FontWeight.w600 : FontWeight.normal,
                    color: isQueried
                        ? (isDelayed ? delayColor(delayMinutes) : kOnTimeGreen)
                        : Colors.grey[600],
                  ),
                ),
                // Delay badge for the queried row
                if (isQueried && isDelayed) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: delayColor(delayMinutes).withAlpha(28),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+${delayMinutes.toStringAsFixed(0)} min',
                      style: TextStyle(
                        fontSize: 11,
                        color: delayColor(delayMinutes),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (isQueried) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: kOnTimeGreen.withAlpha(28),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'On time',
                      style: TextStyle(
                        fontSize: 11,
                        color: kOnTimeGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (isQueried) ...[
                  const Spacer(),
                  Text(
                    '← your query',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 10),
        Text(
          'Estimated from typical $headway-min frequency for this time of day. '
          'For live departures visit traveline.cymru.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}
