/// Riverpod provider for today's service alerts derived from calendar_dates.txt.
///
/// Auto-fetches on first watch. Exposes an [AsyncValue<List<ServiceAlert>>]
/// so the UI can handle loading / error / data states elegantly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/gtfs_model.dart';
import '../../../data/repositories/service_alerts_repository.dart';

/// Singleton repository instance (shared across providers).
final _serviceAlertsRepoProvider = Provider<ServiceAlertsRepository>((ref) {
  return ServiceAlertsRepository();
});

/// Async provider that resolves today's service alerts.
///
/// Usage in widgets:
/// ```dart
/// final alertsAsync = ref.watch(serviceAlertsProvider);
/// alertsAsync.when(
///   data: (alerts) => ...,
///   loading: () => ...,
///   error: (e, _) => ...,
/// );
/// ```
final serviceAlertsProvider =
    FutureProvider<List<ServiceAlert>>((ref) async {
  final repo = ref.read(_serviceAlertsRepoProvider);
  return repo.getTodaysAlerts();
});
