import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/model/route.dart';

void main() {
  group('Route model', () {
    test('fromJson converts seconds to minutes and meters to km', () {
      final json = {
        'geometry': {
          'coordinates': [
            [30.0, 10.0],
            [31.0, 11.0]
          ]
        },
        'eta': 120.0,        // 120 seconds
        'distance': 5000.0,  // 5000 meters
        'destination': 'Central'
      };

      final r = Route.fromJson(json);
      expect(r.coordinates.length, 2);
      expect(r.eta, 2.0);          // 120s / 60 = 2 minutes
      expect(r.distance, 5.0);     // 5000m / 1000 = 5 km
      expect(r.destination, 'Central');
    });

    test('fromJson prefers explicit eta_seconds and distance_meters', () {
      final json = {
        'geometry': {
          'coordinates': [
            [-0.187, 5.604]
          ]
        },
        'eta': 999.0,                // legacy field (should be ignored)
        'distance': 999.0,           // legacy field (should be ignored)
        'eta_seconds': 1800.0,       // 30 minutes
        'distance_meters': 12000.0,  // 12 km
        'destination': 'Madina'
      };

      final r = Route.fromJson(json);
      expect(r.eta, 30.0);       // 1800s / 60
      expect(r.distance, 12.0);  // 12000m / 1000
    });

    test('fromJson handles zero eta and distance', () {
      final json = {
        'geometry': {'coordinates': []},
        'eta': 0.0,
        'distance': 0.0,
        'destination': ''
      };

      final r = Route.fromJson(json);
      expect(r.eta, 0.0);
      expect(r.distance, 0.0);
    });

    test('fromJson handles missing eta and distance', () {
      final json = {
        'geometry': {'coordinates': []},
        'destination': 'Test'
      };

      final r = Route.fromJson(json);
      expect(r.eta, 0.0);
      expect(r.distance, 0.0);
    });

    test('fromMap preserves values (already converted)', () {
      final map = {
        'coordinates': [
          [30.0, 10.0]
        ],
        'eta': 5.5,        // already in minutes
        'distance': 3.2,   // already in km
        'destination': 'Lapaz'
      };

      final r = Route.fromMap(map);
      expect(r.eta, 5.5);
      expect(r.distance, 3.2);
    });

    test('toMap produces correct structure', () {
      final r = Route(
        coordinates: [[30.0, 10.0]],
        eta: 15.0,
        distance: 8.5,
        destination: 'Circle',
      );

      final map = r.toMap();
      expect(map['eta'], 15.0);
      expect(map['distance'], 8.5);
      expect(map['destination'], 'Circle');
    });

    test('coordinates are in GeoJSON format [lng, lat]', () {
      final json = {
        'geometry': {
          'coordinates': [
            [-0.187, 5.604],
            [-0.190, 5.610],
          ]
        },
        'eta': 300.0,
        'distance': 2000.0,
        'destination': 'Madina'
      };

      final r = Route.fromJson(json);
      expect(r.coordinates[0][0], -0.187); // longitude first
      expect(r.coordinates[0][1], 5.604);  // latitude second
    });
  });
}
