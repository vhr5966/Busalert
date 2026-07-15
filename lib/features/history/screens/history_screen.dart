/// Journey history screen showing the user's past bus journeys.
///
/// Displays each journey with date, route, boarding/alighting stops,
/// and recorded duration. Pull-to-refresh reloads from the backend.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(historyProvider.notifier).loadHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey History'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(historyProvider.notifier).loadHistory(),
        child: _buildContent(state),
      ),
    );
  }

  Widget _buildContent(HistoryState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              state.error!.userMessage,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(historyProvider.notifier).loadHistory(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.journeys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No journeys recorded yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking to see your bus journeys here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[400],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.journeys.length,
      itemBuilder: (context, index) {
        final journey = state.journeys[index];
        final duration = journey.durationMinutes;

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: kCardiffBlueLight,
              child: Text(
                journey.busLine,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kCardiffBlue,
                ),
              ),
            ),
            title: Text(
              'Bus ${journey.busLine} — ${journey.boardStopName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (journey.alightStopName != null)
                  Text('→ ${journey.alightStopName}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      formatDate(journey.boardingTime),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      formatTime(journey.boardingTime),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
            trailing: duration != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatDurationMinutes(duration),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: duration > 30 ? kDelayRed : kOnTimeGreen,
                        ),
                      ),
                      Text(
                        'duration',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  )
                : const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        );
      },
    );
  }
}
