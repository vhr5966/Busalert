/// Today's service alerts banner widget.
///
/// Reads [serviceAlertsProvider] and renders a horizontally scrollable row
/// of colour-coded alert chips for each route with a GTFS calendar exception
/// today. Removed-service alerts are red; added-service alerts are blue.
///
/// The banner is completely hidden when there are no alerts, so it adds
/// zero visual noise on normal operating days.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/gtfs_model.dart';
import '../../../data/services/stop_service.dart';
import '../../timetable/screens/route_timetable_screen.dart';
import '../providers/service_alerts_provider.dart';

class ServiceAlertsBanner extends ConsumerStatefulWidget {
  const ServiceAlertsBanner({super.key});

  @override
  ConsumerState<ServiceAlertsBanner> createState() =>
      _ServiceAlertsBannerState();
}

class _ServiceAlertsBannerState extends ConsumerState<ServiceAlertsBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final alertsAsync = ref.watch(serviceAlertsProvider);

    return alertsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
      data: (alerts) {
        if (alerts.isEmpty) {
          return const SizedBox.shrink();
        }
        return _BannerCard(
          alerts: alerts,
          onDismiss: () => setState(() => _dismissed = true),
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final List<ServiceAlert> alerts;
  final VoidCallback onDismiss;

  const _BannerCard({required this.alerts, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    // Determine dominant severity for header colour
    final hasRemoved = alerts.any((a) => a.exceptionType == 2);
    final hasModified = alerts.any((a) => a.exceptionType == 3);
    final headerColor = hasRemoved
        ? const Color(0xFFD32F2F)
        : (hasModified ? const Color(0xFFE65100) : const Color(0xFF1565C0));
    final headerBg = headerColor.withAlpha(18);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withAlpha(60), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  hasRemoved
                      ? Icons.warning_amber_rounded
                      : (hasModified ? Icons.schedule : Icons.info_outline),
                  size: 18,
                  color: headerColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Today's Service Alerts",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: headerColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(Icons.close, size: 16, color: headerColor),
                ),
              ],
            ),
          ),

          const Divider(height: 1, indent: 14, endIndent: 14),

          // ── Horizontally scrollable alert chips ───────────────────
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: alerts.length,
              separatorBuilder: (context, idx) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _AlertChip(alert: alerts[i]),
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _AlertChip extends ConsumerWidget {
  final ServiceAlert alert;

  const _AlertChip({required this.alert});

  void _showDetailsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AlertDetailsSheet(alert: alert),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chipText = alert.customMessage ??
        (alert.exceptionType == 2
            ? 'Route ${alert.routeShortName} — No service today'
            : (alert.exceptionType == 3
                ? 'Route ${alert.routeShortName} — Live traffic delay'
                : 'Route ${alert.routeShortName} — Special service'));

    return Tooltip(
      message: 'Tap for details: ${alert.description}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDetailsModal(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: alert.color.withAlpha(22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: alert.color.withAlpha(90), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(alert.icon, size: 13, color: alert.color),
                const SizedBox(width: 5),
                Text(
                  chipText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: alert.color,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: alert.color.withAlpha(180)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertDetailsSheet extends ConsumerWidget {
  final ServiceAlert alert;

  const _AlertDetailsSheet({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String statusHeader;
    final String statusSubtitle;
    final String detailExplanation;
    final String actionButtonLabel;

    switch (alert.exceptionType) {
      case 2:
        statusHeader = 'No Service Today';
        statusSubtitle = 'Route ${alert.routeShortName} has no scheduled departures today';
        detailExplanation =
            'All scheduled trips for Route ${alert.routeShortName} are cancelled on this date (e.g. Christmas Day or specialized holiday closure). Please choose an alternative route.';
        actionButtonLabel = 'View Route ${alert.routeShortName} Stops & Alternatives';
        break;
      case 1:
        statusHeader = 'Special Service Operating';
        statusSubtitle = 'Additional bus trips running on Route ${alert.routeShortName}';
        detailExplanation =
            'Special event or bank-holiday extra services are operating on Route ${alert.routeShortName} today. Check live tracking for active vehicle positions.';
        actionButtonLabel = 'Check Live Timetable & Delays for Route ${alert.routeShortName}';
        break;
      case 3:
      default:
        statusHeader = 'Live Traffic Delays Active';
        statusSubtitle = 'Route ${alert.routeShortName} is experiencing live delays on the network';
        detailExplanation =
            'Route ${alert.routeShortName} is currently operating with active traffic delays detected across the network. Departure predictions and countdowns are dynamically adjusted based on live vehicle telemetry.';
        actionButtonLabel = 'Check Live Timetable & Delays for Route ${alert.routeShortName}';
        break;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: alert.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: alert.color.withAlpha(100)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(alert.icon, size: 16, color: alert.color),
                    const SizedBox(width: 6),
                    Text(
                      'Route ${alert.routeShortName}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: alert.color,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status title
          Text(
            statusHeader,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          // Information box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF475569), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    detailExplanation,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action button: view live timetable and predictions for this route
          ElevatedButton.icon(
            icon: const Icon(Icons.insights_rounded, size: 18),
            label: Text(actionButtonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: alert.color,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                final stopService = StopService();
                final allStops = await stopService.getStops();
                final targetStop = allStops.firstWhere(
                  (s) => s.routes.contains(alert.routeShortName),
                  orElse: () => allStops.first,
                );

                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RouteTimetableScreen(
                        routeNumber: alert.routeShortName,
                        stop: targetStop,
                      ),
                    ),
                  );
                }
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }
}
