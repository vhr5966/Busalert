import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/models/bus_stop.dart';
import 'package:busalert/features/map/providers/map_provider.dart';

void main() {
  group('MapProvider Search Tests', () {
    const stop1 = BusStop(
      id: 101,
      name: 'Kingsway Stop A',
      latitude: 51.4816,
      longitude: -3.1791,
      routes: ['27', '28'],
    );
    const stop2 = BusStop(
      id: 102,
      name: 'Greyfriars Road',
      latitude: 51.4830,
      longitude: -3.1770,
      routes: ['35', '36'],
    );
    const stop3 = BusStop(
      id: 103,
      name: 'Customhouse Street',
      latitude: 51.4780,
      longitude: -3.1750,
      routes: ['X2', '304'],
    );

    test('Initial MapState has empty searchQuery and returns all stops in filteredStops', () {
      const state = MapState(stops: [stop1, stop2, stop3]);
      expect(state.searchQuery, isEmpty);
      expect(state.filteredStops.length, equals(3));
    });

    test('Filtering by stop name (case insensitive)', () {
      const state = MapState(
        stops: [stop1, stop2, stop3],
        searchQuery: 'kingsway',
      );
      expect(state.filteredStops.length, equals(1));
      expect(state.filteredStops.first.name, equals('Kingsway Stop A'));
    });

    test('Filtering by stop ID', () {
      const state = MapState(
        stops: [stop1, stop2, stop3],
        searchQuery: '102',
      );
      expect(state.filteredStops.length, equals(1));
      expect(state.filteredStops.first.name, equals('Greyfriars Road'));
    });

    test('Filtering by route number', () {
      const state = MapState(
        stops: [stop1, stop2, stop3],
        searchQuery: '304',
      );
      expect(state.filteredStops.length, equals(1));
      expect(state.filteredStops.first.name, equals('Customhouse Street'));
    });
  });
}
