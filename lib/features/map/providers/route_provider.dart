/// Riverpod state notifier for fetching and filtering official bus routes from /api/routes.
///
/// Handles search filtering by route number, route name, and operator name.
/// Displays truthful unavailable error state when feed access is unconfigured.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/bus_route.dart';
import '../../../data/repositories/route_repository.dart';

final RouteRepository _routeRepository = RouteRepository();

class RouteListState {
  final List<BusRoute> routes;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const RouteListState({
    this.routes = const [],
    this.searchQuery = '',
    this.isLoading = true,
    this.error,
  });

  /// Filtered routes matching search query against number, name, or operator.
  List<BusRoute> get filteredRoutes {
    if (searchQuery.trim().isEmpty) return routes;
    final query = searchQuery.trim().toLowerCase();
    return routes.where((r) {
      final numberMatch = r.number.toLowerCase().contains(query);
      final nameMatch = r.name.toLowerCase().contains(query);
      final operatorMatch = r.operatorName.toLowerCase().contains(query) ||
          r.operatorId.toLowerCase().contains(query);
      return numberMatch || nameMatch || operatorMatch;
    }).toList();
  }

  RouteListState copyWith({
    List<BusRoute>? routes,
    String? searchQuery,
    bool? isLoading,
    String? error,
  }) {
    return RouteListState(
      routes: routes ?? this.routes,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class RouteNotifier extends StateNotifier<RouteListState> {
  RouteNotifier() : super(const RouteListState()) {
    loadRoutes();
  }

  Future<void> loadRoutes() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // RouteRepository returns either live backend data or the official
      // Cardiff reference dataset — never truly empty.
      final routes = await _routeRepository.getRoutes();
      state = RouteListState(
        routes: routes,
        isLoading: false,
        error: null,
      );
    } catch (_) {
      state = const RouteListState(
        routes: [],
        isLoading: false,
        error: 'Route information is currently unavailable.',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final routeProvider =
    StateNotifierProvider<RouteNotifier, RouteListState>((ref) {
  return RouteNotifier();
});
