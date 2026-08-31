/// Searchable modal bottom sheet to select a destination bus stop.
///
/// Provides real-time filtering across all Cardiff Bus stops with route badges
/// and location indicators.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/models/bus_stop.dart';

/// Shows the destination stop picker modal and returns the chosen [BusStop].
Future<BusStop?> showDestinationPicker(
  BuildContext context, {
  required List<BusStop> stops,
  BusStop? selectedStop,
  String title = 'Choose Destination Stop',
}) {
  return showModalBottomSheet<BusStop>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _DestinationPickerSheet(
      stops: stops,
      selectedStop: selectedStop,
      title: title,
    ),
  );
}

class _DestinationPickerSheet extends StatefulWidget {
  final List<BusStop> stops;
  final BusStop? selectedStop;
  final String title;

  const _DestinationPickerSheet({
    required this.stops,
    this.selectedStop,
    required this.title,
  });

  @override
  State<_DestinationPickerSheet> createState() =>
      _DestinationPickerSheetState();
}

class _DestinationPickerSheetState extends State<_DestinationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<BusStop> _filteredStops = [];

  @override
  void initState() {
    super.initState();
    _filteredStops = widget.stops;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStops(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredStops = widget.stops);
      return;
    }

    final q = query.trim().toLowerCase();
    setState(() {
      _filteredStops = widget.stops.where((s) {
        final nameMatch = s.name.toLowerCase().contains(q);
        final routeMatch = s.routes.any((r) => r.toLowerCase().contains(q));
        return nameMatch || routeMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          // ── Drag Handle ───────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kCardiffBlue.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: kCardiffBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ── Search Input ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by stop name or route number...',
                prefixIcon: const Icon(Icons.search, color: kCardiffBlue),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterStops('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _filterStops,
            ),
          ),

          // ── Stop Count ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_filteredStops.length} stops available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Stops List ────────────────────────────────────────────
          Expanded(
            child: _filteredStops.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'No bus stops matching "${_searchController.text}"',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredStops.length,
                    itemBuilder: (context, index) {
                      final stop = _filteredStops[index];
                      final isSelected = stop.id == widget.selectedStop?.id;

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? kCardiffBlue
                                : kCardiffBlue.withAlpha(15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.directions_bus,
                            size: 18,
                            color: isSelected ? Colors.white : kCardiffBlue,
                          ),
                        ),
                        title: Text(
                          stop.name,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? kCardiffBlue : kTextPrimary,
                          ),
                        ),
                        subtitle: stop.routes.isNotEmpty
                            ? Text(
                                'Lines: ${stop.routes.take(5).join(', ')}${stop.routes.length > 5 ? '…' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: kCardiffBlue)
                            : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        onTap: () => Navigator.pop(context, stop),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
