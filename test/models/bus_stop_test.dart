import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/model/bus_stop.dart';

void main() {
  group('BusStop model', () {
    test('fromJson parses GeoJSON feature correctly', () {
      final feature = {
        'geometry': {
          'coordinates': [30.0, 10.5]
        },
        'properties': {
          'system_id': 'stop-123',
          'destinations': {'Center': 3, 'North': 2},
          'total_count': 5,
        }
      };

      final stop = BusStop.fromJson(feature);

      expect(stop.systemId, 'stop-123');
      expect(stop.latitude, 10.5);
      expect(stop.longitude, 30.0);
      expect(stop.destinations['Center'], 3);
      expect(stop.destinations['North'], 2);
      expect(stop.totalCount, 5);

      final map = stop.toMap();
      expect(map['systemId'], 'stop-123');
      expect(map['latitude'], 10.5);
    });

    test('copyWith and fromMap work', () {
      final stop = BusStop(
        systemId: 's1',
        latitude: 1.0,
        longitude: 2.0,
        destinations: {'A': 1},
        totalCount: 1,
      );

      final copy = stop.copyWith(latitude: 3.3);
      expect(copy.latitude, 3.3);

      final map = stop.toMap();
      final fromMap = BusStop.fromMap(map);
      expect(fromMap.systemId, stop.systemId);
      expect(fromMap.totalCount, stop.totalCount);
    });
  });
}
