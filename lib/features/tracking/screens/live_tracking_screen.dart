/// Live journey tracking screen.
///
/// Displays the current GPS tracking status — whether the app is searching
/// for a bus, the user is on a bus, or a journey has been completed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../providers/tracking_provider.dart';
import '../services/gps_tracker.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  @override
  void initState() {
    super.initState();
    // Load bus stops for the tracking system
    ref.read(trackingProvider.notifier).init();
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Status Card ─────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Status icon
                    _buildStatusIcon(trackingState),
                    const SizedBox(height: 16),

                    // Status text
                    Text(
                      _statusTitle(trackingState),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusSubtitle(trackingState),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Journey Details (if on bus) ─────────────────────────
            if (trackingState is TrackingOnBus) ...[
              _DetailRow(
                icon: Icons.location_on,
                label: 'Boarding stop',
                value: trackingState.boardStop.name,
              ),
              _DetailRow(
                icon: Icons.route,
                label: 'Bus line',
                value: trackingState.busLine,
              ),
              _DetailRow(
                icon: Icons.access_time,
                label: 'Boarding time',
                value: _formatTime(trackingState.boardingTime),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ride the bus — alighting will be detected automatically.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // ── Control Button ──────────────────────────────────────
            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggleTracking(trackingState),
                icon: Icon(
                  trackingState is TrackingIdle ||
                          trackingState is TrackingJourneyComplete ||
                          trackingState is TrackingError
                      ? Icons.play_arrow
                      : Icons.stop,
                ),
                label: Text(
                  trackingState is TrackingIdle ||
                          trackingState is TrackingJourneyComplete ||
                          trackingState is TrackingError
                      ? 'Start Tracking'
                      : 'Stop Tracking',
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(TrackingState state) {
    IconData icon;
    Color color;

    switch (state) {
      case TrackingIdle():
        icon = Icons.gps_fixed;
        color = Colors.grey;
      case TrackingSearching():
        icon = Icons.radar;
        color = kAmberAccent;
      case TrackingOnBus():
        icon = Icons.directions_bus;
        color = kCardiffBlue;
      case TrackingJourneyComplete():
        icon = Icons.check_circle;
        color = kOnTimeGreen;
      case TrackingError():
        icon = Icons.error;
        color = kDelayRed;
    }

    return Icon(icon, size: 64, color: color);
  }

  String _statusTitle(TrackingState state) => switch (state) {
        TrackingIdle() => 'Ready to Track',
        TrackingSearching() => 'Searching for Bus...',
        TrackingOnBus() => 'On the Bus!',
        TrackingJourneyComplete() => 'Journey Recorded!',
        TrackingError() => 'Tracking Error',
      };

  String _statusSubtitle(TrackingState state) => switch (state) {
        TrackingIdle() => 'Tap "Start Tracking" to begin',
        TrackingSearching() => 'Waiting for GPS signal near a bus stop',
        TrackingOnBus() => 'Your journey is being recorded',
        TrackingJourneyComplete() => 'Submitted successfully',
        TrackingError() => (state).message,
      };

  VoidCallback? _toggleTracking(TrackingState state) {
    // Start tracking from idle, completed, or error states
    if (state is TrackingIdle ||
        state is TrackingJourneyComplete ||
        state is TrackingError) {
      return () async {
        // Show GDPR-style consent dialog before enabling GPS.
        final consented = await GpsTracker.showGpsConsentDialog(context);
        if (!mounted) return;
        if (consented) {
          ref.read(trackingProvider.notifier).startTracking();
        }
      };
    }
    // Stop tracking when searching or on bus
    if (state is TrackingSearching || state is TrackingOnBus) {
      return () => ref.read(trackingProvider.notifier).stopTracking();
    }
    return null;
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: kCardiffBlue),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
              ),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ],
      ),
    );
  }
}
