import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/model/vehicle_model.dart';

void main() {
  group('VehicleModel', () {
    test('fromJson and toJson roundtrip', () {
      final json = {
        'vehicle_id': 'v1',
        'driver_id': 'd1',
        'plate_number': 'ABC-123',
        'brand': 'Toyota',
        'model': 'Hiace',
        'year': '2015',
        'color': 'white',
        'seating_capacity': 20,
      };

      final v = VehicleModel.fromJson(json);

      expect(v.vehicleId, 'v1');
      expect(v.plateNumber, 'ABC-123');
      expect(v.brand, 'Toyota');
      expect(v.seatingCapacity, 20);

      final out = v.toJson();
      expect(out['plate_number'], 'ABC-123');
      expect(out['brand'], 'Toyota');
    });

    test('displayName and copyWith', () {
      final v = VehicleModel(
        vehicleId: 'v2',
        plateNumber: 'XYZ-999',
        brand: 'Ford',
        model: 'Transit',
        year: '2018',
        color: 'blue',
      );

      expect(v.displayName.contains('Ford'), isTrue);
      final updated = v.copyWith(color: 'red');
      expect(updated.color, 'red');
    });
  });
}
