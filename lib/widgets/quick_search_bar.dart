/// Quick global search bar for BusAlert.
///
/// Searches across both bus stops (by name) and routes (by number) in a
/// single Material 3 [SearchAnchor] overlay. Tapping a result:
/// - **Stop result** → pre-selects the stop on the Predict tab and navigates there
/// - **Route result** → filters the Routes tab and navigates there
///
/// All search runs synchronously against in-memory lists — no network call.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/models/bus_stop.dart';
import '../data/repositories/gtfs_repository.dart';
import '../data/services/stop_service.dart';
import '../features/timetable/screens/route_timetable_screen.dart';

// ── Search result types ────────────────────────────────────────────────────

sealed class _SearchResult {
  const _SearchResult();
}

class _StopResult extends _SearchResult {
  final BusStop stop;
  const _StopResult(this.stop);
}

class _RouteResult extends _SearchResult {
  final String routeNumber;
  const _RouteResult(this.routeNumber);
}

// ── Widget ─────────────────────────────────────────────────────────────────

/// Search icon button that expands into a full [SearchAnchor] overlay.
///
/// [onNavigate] is called with the tab index the host shell should switch to:
/// * 0 → Predict
/// * 1 → Routes
class QuickSearchBar extends ConsumerStatefulWidget {
  /// Called when a result is selected, with the destination tab index.
  final ValueChanged<int> onNavigate;

  const QuickSearchBar({super.key, required this.onNavigate});

  @override
  ConsumerState<QuickSearchBar> createState() => _QuickSearchBarState();
}

class _QuickSearchBarState extends ConsumerState<QuickSearchBar> {
  final SearchController _controller = SearchController();

  // Cached in-memory data loaded once
  List<BusStop> _stops = [];
  final List<String> _routeNumbers = [];
  bool _loaded = false;

  // Max suggestions shown per category
  static const int _maxStops = 6;
  static const int _maxRoutes = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_loaded) return;
    try {
      // Load stops
      final stopService = StopService();
      _stops = await stopService.getStops();

      // Load routes from GTFS (already parsed on Routes tab, but we want short names here)
      final gtfs = GtfsRepository();
      await gtfs.loadGtfsData();
      final seen = <String>{};
      for (final route in gtfs.routes) {
        if (seen.add(route.shortName)) {
          _routeNumbers.add(route.shortName);
        }
      }
      // Sort routes naturally (1, 1A, 2, … 101)
      _routeNumbers.sort((a, b) {
        final aNum = int.tryParse(RegExp(r'\d+').stringMatch(a) ?? '') ?? 999;
        final bNum = int.tryParse(RegExp(r'\d+').stringMatch(b) ?? '') ?? 999;
        if (aNum != bNum) return aNum.compareTo(bNum);
        return a.compareTo(b);
      });

      _loaded = true;
    } catch (_) {
      // Data loading is best-effort; search will just return empty
    }
  }

  List<_SearchResult> _search(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final results = <_SearchResult>[];

    // Route matches (exact prefix first)
    final exactRoutes = _routeNumbers
        .where((r) => r.toLowerCase().startsWith(q))
        .take(_maxRoutes)
        .map((r) => _RouteResult(r))
        .toList();
    results.addAll(exactRoutes);

    // Partial route matches if fewer than max
    if (exactRoutes.length < _maxRoutes) {
      final partial = _routeNumbers
          .where((r) =>
              !r.toLowerCase().startsWith(q) &&
              r.toLowerCase().contains(q))
          .take(_maxRoutes - exactRoutes.length)
          .map((r) => _RouteResult(r));
      results.addAll(partial);
    }

    // Stop name matches
    final stopMatches = _stops
        .where((s) => s.name.toLowerCase().contains(q))
        .take(_maxStops)
        .map((s) => _StopResult(s))
        .toList();
    results.addAll(stopMatches);

    return results;
  }

  void _onResultSelected(_SearchResult result) {
    _controller.closeView('');

    if (result is _StopResult) {
      final route = result.stop.routes.isNotEmpty ? result.stop.routes.first : '27';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RouteTimetableScreen(
            routeNumber: route,
            stop: result.stop,
          ),
        ),
      );
    } else if (result is _RouteResult) {
      final matchingStop = _stops.firstWhere(
        (s) => s.routes.contains(result.routeNumber),
        orElse: () => _stops.isNotEmpty ? _stops.first : const BusStop(id: 1, name: 'Cardiff Central', latitude: 51.478, longitude: -3.178, atcoCode: '5810WDB48488', routes: ['27']),
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RouteTimetableScreen(
            routeNumber: result.routeNumber,
            stop: matchingStop,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _controller,
      viewHintText: 'Search stops or routes…',
      viewLeading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _controller.closeView(''),
      ),
      viewTrailing: [
        if (_controller.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _controller.clear();
              _controller.openView();
            },
          ),
      ],
      builder: (context, controller) {
        return IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Quick search',
          onPressed: controller.openView,
        );
      },
      suggestionsBuilder: (context, controller) {
        final query = controller.text;
        final results = _search(query);

        if (query.trim().isEmpty) {
          return [
            _SuggestionHint(
              text: 'Type a route number (e.g. 27) or stop name',
            ),
          ];
        }

        if (results.isEmpty) {
          return [
            _SuggestionHint(
              text: 'No results for "$query"',
            ),
          ];
        }

        final widgets = <Widget>[];

        // Group header: Routes
        final routeResults = results.whereType<_RouteResult>().toList();
        final stopResults = results.whereType<_StopResult>().toList();

        if (routeResults.isNotEmpty) {
          widgets.add(_GroupHeader(label: 'Routes'));
          for (final r in routeResults) {
            widgets.add(_RouteResultTile(
              routeNumber: r.routeNumber,
              onTap: () => _onResultSelected(r),
            ));
          }
        }

        if (stopResults.isNotEmpty) {
          widgets.add(_GroupHeader(label: 'Bus Stops'));
          for (final s in stopResults) {
            widgets.add(_StopResultTile(
              stop: s.stop,
              query: query,
              onTap: () => _onResultSelected(s),
            ));
          }
        }

        return widgets;
      },
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _SuggestionHint extends StatelessWidget {
  final String text;
  const _SuggestionHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _RouteResultTile extends StatelessWidget {
  final String routeNumber;
  final VoidCallback onTap;
  const _RouteResultTile({required this.routeNumber, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: kCardiffBlue.withAlpha(22),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            routeNumber,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: kCardiffBlue,
            ),
          ),
        ),
      ),
      title: Text('Route $routeNumber'),
      subtitle: const Text('View route on map'),
      trailing: const Icon(Icons.alt_route, size: 18, color: kCardiffBlue),
      onTap: onTap,
    );
  }
}

class _StopResultTile extends StatelessWidget {
  final BusStop stop;
  final String query;
  final VoidCallback onTap;

  const _StopResultTile({
    required this.stop,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.teal.withAlpha(22),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.directions_bus, size: 20, color: Colors.teal),
      ),
      title: _HighlightText(text: stop.name, query: query),
      subtitle: stop.routes.isNotEmpty
          ? Text(
              stop.routes.take(4).join(' · '),
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: const Icon(Icons.analytics_outlined, size: 18, color: Colors.teal),
      onTap: onTap,
    );
  }
}

/// Highlights [query] substring in [text] with bold.
class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  const _HighlightText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final idx = text.toLowerCase().indexOf(q);

    if (idx < 0 || q.isEmpty) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return Text.rich(
      TextSpan(
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + q.length),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (idx + q.length < text.length)
            TextSpan(text: text.substring(idx + q.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
