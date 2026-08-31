/// Detailed prediction result screen.
///
/// Displays the predicted delay based on historical user journey records.
/// Displays truthful data availability warnings when data is insufficient.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/models/prediction.dart';

class PredictionResultScreen extends StatelessWidget {
  final Prediction prediction;

  const PredictionResultScreen({super.key, required this.prediction});

  @override
  Widget build(BuildContext context) {
    final hasEnoughData = prediction.sampleSize > 0;
    final delay = prediction.predictedDelayMinutes;
    final color = hasEnoughData ? delayColor(delay) : Colors.grey;
    final label = hasEnoughData ? delayLabel(delay) : 'Data Unavailable';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prediction Result'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!hasEnoughData)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, size: 56, color: Colors.amber.shade800),
                      const SizedBox(height: 16),
                      Text(
                        'Not enough real-time data is available for a reliable prediction.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Predictions are derived strictly from verified historical journey recordings.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
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
            ],

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

            // ── Side-by-Side Comparison Card ──────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.compare_arrows_rounded, color: kCardiffBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Timetable vs. Predicted Delay',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        // Scheduled
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SCHEDULED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  prediction.timeOfDay,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Official Timetable',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Predicted
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withAlpha(80)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PREDICTED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _calculateAdjustedTime(prediction.timeOfDay, prediction.predictedDelayMinutes),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  prediction.predictedDelayMinutes >= 0
                                      ? '+${prediction.predictedDelayMinutes.toStringAsFixed(1)} min delay'
                                      : '${prediction.predictedDelayMinutes.toStringAsFixed(1)} min early',
                                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
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
            ),
            const SizedBox(height: 16),

            if (hasEnoughData)
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
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _calculateAdjustedTime(String timeOfDay, double delayMinutes) {
    try {
      final parts = timeOfDay.split(':');
      if (parts.length == 2) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final now = DateTime.now();
        final base = DateTime(now.year, now.month, now.day, hours, minutes);
        final adjusted = base.add(Duration(minutes: delayMinutes.round()));
        final h = adjusted.hour.toString().padLeft(2, '0');
        final m = adjusted.minute.toString().padLeft(2, '0');
        return '$h:$m';
      }
    } catch (_) {}
    return timeOfDay;
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}
