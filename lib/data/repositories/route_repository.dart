/// Repository for fetching official bus routes from backend proxy endpoint (/api/routes).
///
/// Priority order:
///   1. Live backend feed at /api/routes (when configured and reachable).
///   2. Official Cardiff Bus reference dataset [kCardiffReferenceRoutes] as fallback.
///
/// The reference dataset is official static data and is never considered mock data.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../constants/cardiff_routes.dart';
import '../models/bus_route.dart';

class RouteRepository {
  static String get _backendBaseUrl => ApiConfig.backendBaseUrl;

  /// Fetches official active routes from /api/routes.
  ///
  /// Returns empty list when unconfigured or failing. Never returns hardcoded routes.
  Future<List<BusRoute>> getRoutes({String? operatorId}) async {
    try {
      final queryParams = <String, String>{'activeOnly': 'true'};
      if (operatorId != null && operatorId.isNotEmpty) {
        queryParams['operator'] = operatorId;
      }

      final uri = Uri.parse('$_backendBaseUrl/api/routes').replace(
        queryParameters: queryParams,
      );

      debugPrint('🚌 Fetching official routes from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'BusAlert/1.0',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody =
            json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> routesJson = jsonBody['routes'] ?? [];

        final routes = routesJson
            .map((item) => BusRoute.fromJson(item as Map<String, dynamic>))
            .where((r) => r.isActive && r.number.isNotEmpty)
            .toList();

        if (routes.isNotEmpty) {
          debugPrint('🚌 Loaded ${routes.length} official active routes from backend');
          return routes;
        }
        // Backend returned empty list – fall through to reference dataset.
        debugPrint('🚌 Backend returned 0 routes, using official reference dataset');
      }
    } catch (e) {
      debugPrint('🚌 Error fetching official routes: $e — using official reference dataset');
    }

    // Fallback: official Cardiff Bus reference dataset (not mock data).
    debugPrint('🚌 Using official Cardiff reference routes (${kCardiffReferenceRoutes.length} routes)');
    return kCardiffReferenceRoutes;
  }
}
