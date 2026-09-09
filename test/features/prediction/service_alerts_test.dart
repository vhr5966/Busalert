import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/models/gtfs_model.dart';
import 'package:flutter/material.dart';

void main() {
  group('ServiceAlert Model Tests', () {
    test('ServiceAlert description and color for service removal (exceptionType = 2)', () {
      const alert = ServiceAlert(
        routeShortName: '4',
        exceptionType: 2,
      );

      expect(alert.description, equals('Route 4 — no service today'));
      expect(alert.color, equals(const Color(0xFFD32F2F)));
      expect(alert.icon, equals(Icons.cancel_outlined));
    });

    test('ServiceAlert description and color for added service (exceptionType = 1)', () {
      const alert = ServiceAlert(
        routeShortName: 'Sky',
        exceptionType: 1,
      );

      expect(alert.description, equals('Route Sky — special service running today'));
      expect(alert.color, equals(const Color(0xFF1565C0)));
      expect(alert.icon, equals(Icons.directions_bus));
    });
  });
}
