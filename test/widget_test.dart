// BusAlert Cardiff — Tests
//
// Since Firebase requires platform channels unavailable in the test
// environment, this test suite focuses on the non-Firebase logic:
// data models, GPS detection utilities, and app structure.
//
// Full integration tests require running on a real device or emulator
// after configuring Firebase via `flutterfire configure`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/models/bus_stop.dart';
import 'package:busalert/data/models/journey.dart';
import 'package:busalert/data/models/prediction.dart';
import 'package:busalert/core/theme.dart';
import 'package:busalert/core/constants.dart';

void main() {
  group('BusStop model', () {
    test('fromJson creates BusStop from map', () {
      final stop = BusStop.fromJson({
        'id': 1,
        'name': 'Cardiff Central Station',
        'latitude': 51.4757,
        'longitude': -3.1791,
      });

      expect(stop.id, equals(1));
      expect(stop.name, equals('Cardiff Central Station'));
      expect(stop.latitude, closeTo(51.4757, 0.0001));
    });

    test('distanceTo calculates Haversine distance', () {
      final stop = BusStop.fromJson({
        'id': 1,
        'name': 'Test Stop',
        'latitude': 51.5,
        'longitude': -3.2,
      });

      // Distance to a point ~50m away
      final distance = stop.distanceTo(51.5005, -3.2);
      expect(distance, greaterThan(40));
      expect(distance, lessThan(70));
    });

    test('toJson serializes correctly', () {
      final stop = BusStop(
        id: 5,
        name: 'Queen Street',
        latitude: 51.4817,
        longitude: -3.1705,
      );

      final json = stop.toJson();
      expect(json['id'], equals(5));
      expect(json['name'], equals('Queen Street'));
    });

    test('equality works by id', () {
      final a = BusStop(id: 1, name: 'Stop A', latitude: 0, longitude: 0);
      final b = BusStop(id: 1, name: 'Stop B', latitude: 0, longitude: 0);
      final c = BusStop(id: 2, name: 'Stop A', latitude: 0, longitude: 0);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('Journey model', () {
    test('fromJson creates Journey from map', () {
      final journey = Journey.fromJson({
        'id': 42,
        'user_id': 1,
        'board_stop_id': 1,
        'board_stop_name': 'Central Station',
        'board_lat': 51.4757,
        'board_lng': -3.1791,
        'bus_line': '28',
        'boarding_time': '2026-06-30T08:00:00.000Z',
        'alighting_time': '2026-06-30T08:25:00.000Z',
      });

      expect(journey.id, equals(42));
      expect(journey.busLine, equals('28'));
      expect(journey.durationMinutes, equals(25));
    });

    test('durationMinutes returns null for incomplete journey', () {
      final journey = Journey.fromJson({
        'user_id': 1,
        'board_stop_id': 1,
        'board_stop_name': 'Central',
        'board_lat': 0,
        'board_lng': 0,
        'bus_line': '1',
        'boarding_time': '2026-06-30T08:00:00.000Z',
      });

      expect(journey.durationMinutes, isNull);
    });
  });

  group('Prediction model', () {
    test('fromJson and status helpers', () {
      final prediction = Prediction.fromJson({
        'predicted_delay_minutes': 8.5,
        'scheduled_duration_minutes': 25.0,
        'average_actual_duration_minutes': 33.5,
        'confidence_level': 'Medium',
        'sample_size': 15,
        'stop_name': 'Castle Street',
        'bus_line': '28',
        'time_of_day': '08:30',
      });

      expect(prediction.predictedDelayMinutes, closeTo(8.5, 0.01));
      expect(prediction.confidenceLevel, equals('Medium'));
      expect(prediction.isOnTime, isFalse);
      expect(prediction.isMinorDelay, isTrue);
      expect(prediction.isMajorDelay, isFalse);
    });
  });

  group('Theme helpers', () {
    test('delayColor returns correct colors', () {
      expect(delayColor(0), equals(kOnTimeGreen));
      expect(delayColor(2), equals(kOnTimeGreen));
      expect(delayColor(5), equals(kAmberAccent));
      expect(delayColor(10), equals(kAmberAccent));
      expect(delayColor(15), equals(kDelayRed));
    });

    test('delayLabel returns correct labels', () {
      expect(delayLabel(1), equals('On time'));
      expect(delayLabel(5), equals('Minor delay'));
      expect(delayLabel(15), equals('Major delay'));
    });
  });

  group('Constants', () {
    test('has Cardiff bus stop data', () {
      expect(kMockBusStops.length, greaterThan(5));
      expect(kMockBusStops.first['name'], contains('Cardiff'));
    });

    test('has GPS threshold constants', () {
      expect(kStopProximityMeters, equals(50.0));
      expect(kBoardingSpeedThresholdKmh, equals(7.0));
    });
  });
}
