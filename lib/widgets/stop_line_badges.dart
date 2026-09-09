/// Widget that shows the bus lines serving a stop as colored badge chips.
///
/// Uses GTFS route_color / route_text_color for each badge.
/// Falls back to neutral grey when color data is absent.
/// Shows a clear "no lines" message when the list is empty — never falls back
/// to showing all routes.
///
/// When [lines] contains directional entries (i.e. the same route number
/// appears twice with different [GtfsLineInfo.directionId] values), each
/// direction is rendered as a separate row with a "towards X" label, so the
/// user can clearly distinguish both directions.
library;

import 'package:flutter/material.dart';

import '../data/services/gtfs_stop_routes_service.dart';

/// Renders colored route-number badges for [lines].
///
/// Pass the result of [GtfsStopRoutesService.directionalLinesForStop] to get
/// full bidirectional rendering. Passing [linesForStop] output also works and
/// renders simple badges with no direction labels.
///
/// ```dart
/// StopLineBadges(
///   lines: GtfsStopRoutesService.instance.directionalLinesForStop(stop.atcoCode),
/// )
/// ```
class StopLineBadges extends StatelessWidget {
  const StopLineBadges({
    super.key,
    required this.lines,
    this.emptyMessage = 'No scheduled lines found for this stop',
    this.badgeSize = 36.0,
    this.fontSize = 11.0,
    this.wrap = true,
  });

  /// The lines to render. Supply an empty list to show [emptyMessage].
  final List<GtfsLineInfo> lines;

  /// Message shown when [lines] is empty.
  final String emptyMessage;

  /// Diameter of each circular badge.
  final double badgeSize;

  /// Font size inside the badge.
  final double fontSize;

  /// If true (default), wraps badges across multiple lines.
  /// If false, renders a horizontally scrollable single row.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                emptyMessage,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Determine which route short names have >1 direction at this stop.
    // Also detect if the same number appears with different agencies.
    final directionCounts = <String, int>{};  // routeId -> count
    final shortNameAgencies = <String, Set<String>>{};  // shortName -> {agencyIds}
    
    for (final line in lines) {
      directionCounts[line.routeId] = (directionCounts[line.routeId] ?? 0) + 1;
      shortNameAgencies.putIfAbsent(line.shortName, () => {}).add(line.agencyId);
    }
    
    final bidirectionalRoutes = directionCounts.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toSet();
    
    // Routes where we need to show agency (same number, different agencies)
    final multiAgencyNumbers = shortNameAgencies.entries
        .where((e) => e.value.length > 1)
        .map((e) => e.key)
        .toSet();

    // Build a list of badge widgets — rows for bidirectional, plain chips for
    // single-direction routes.
    final widgets = <Widget>[];

    for (final line in lines) {
      final isBidir = bidirectionalRoutes.contains(line.routeId);
      final showAgency = multiAgencyNumbers.contains(line.shortName);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: isBidir
              ? _DirectionalBadge(
                  line: line,
                  badgeSize: badgeSize,
                  fontSize: fontSize,
                  showAgency: showAgency,
                )
              : _RouteBadge(
                  line: line,
                  size: badgeSize,
                  fontSize: fontSize,
                  showAgency: showAgency,
                ),
        ),
      );
    }

    if (wrap) {
      return Wrap(children: widgets);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: widgets),
    );
  }
}

// ── Plain badge (single-direction route) ─────────────────────────────────────

class _RouteBadge extends StatelessWidget {
  const _RouteBadge({
    required this.line,
    required this.size,
    required this.fontSize,
    this.showAgency = false,
  });

  final GtfsLineInfo line;
  final double size;
  final double fontSize;
  final bool showAgency;

  @override
  Widget build(BuildContext context) {
    final label = line.shortName;
    final isLong = label.length > 3;

    Widget badge = Container(
      height: size,
      constraints: BoxConstraints(minWidth: size),
      padding: EdgeInsets.symmetric(horizontal: isLong ? 8 : 4),
      decoration: BoxDecoration(
        color: line.backgroundColor,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: Colors.black.withAlpha(20),
          width: 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: line.textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
          height: 1.0,
        ),
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );

    if (showAgency) {
      return Tooltip(
        message: '${line.agencyId}: ${line.shortName}',
        child: badge,
      );
    }
    return badge;
  }
}

// ── Directional badge (one direction of a bidirectional route) ───────────────
//
// Renders the route number badge on the left, followed by an arrow icon and
// "towards <headsign>" text on the right. Both directions of the same route
// share the same badge color so the user can see they're the same line.

class _DirectionalBadge extends StatelessWidget {
  const _DirectionalBadge({
    required this.line,
    required this.badgeSize,
    required this.fontSize,
    this.showAgency = false,
  });

  final GtfsLineInfo line;
  final double badgeSize;
  final double fontSize;
  final bool showAgency;

  @override
  Widget build(BuildContext context) {
    final label = line.shortName;
    final isLong = label.length > 3;
    final headsign = line.headsign.isNotEmpty ? line.headsign : '—';
    
    // Prepend agency if needed (e.g. "CB 30" when both CB:30 and NB:30 exist)
    final displayLabel = showAgency ? '${line.agencyId} $label' : label;

    return Container(
      height: badgeSize,
      padding: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: line.backgroundColor,
        borderRadius: BorderRadius.circular(badgeSize / 2),
        border: Border.all(
          color: Colors.black.withAlpha(20),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Route number pill
          Container(
            height: badgeSize,
            constraints: BoxConstraints(minWidth: badgeSize),
            padding: EdgeInsets.symmetric(horizontal: isLong ? 8 : 4),
            alignment: Alignment.center,
            child: Text(
              displayLabel,
              style: TextStyle(
                color: line.textColor,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
          // Divider
          Container(
            width: 0.5,
            height: badgeSize * 0.6,
            color: line.textColor.withAlpha(80),
          ),
          const SizedBox(width: 5),
          // Arrow + headsign
          Icon(
            Icons.arrow_forward,
            size: fontSize + 1,
            color: line.textColor,
          ),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              headsign,
              style: TextStyle(
                color: line.textColor,
                fontSize: fontSize - 1,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
