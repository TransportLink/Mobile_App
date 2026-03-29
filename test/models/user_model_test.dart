import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/model/user_model.dart';

void main() {
  group('UserModel', () {
    test('fromMap creates model with all fields', () {
      final map = {
        'id': '123',
        'driver_id': 'drv_456',
        'full_name': 'Kwame Mensah',
        'email': 'kwame@test.com',
        'password_hash': '',
        'phone_number': '0241234567',
        'date_of_birth': '1990-01-15',
        'license_number': 'LIC12345',
        'license_expiry': '2027-06-01',
        'national_id': 'NID98765',
        'profile_photo_url': 'https://example.com/photo.jpg',
      };

      final user = UserModel.fromMap(map);

      expect(user.id, '123');
      expect(user.driverId, 'drv_456');
      expect(user.full_name, 'Kwame Mensah');
      expect(user.email, 'kwame@test.com');
      expect(user.phone_number, '0241234567');
      expect(user.license_number, 'LIC12345');
    });

    test('fromMap handles missing fields with defaults', () {
      final user = UserModel.fromMap({});

      expect(user.id, '');
      expect(user.full_name, '');
      expect(user.email, '');
      expect(user.license_number, '');
      expect(user.driverId, '');
    });

    test('isDriver returns true when license_number is not empty', () {
      final driver = UserModel(
        id: '1',
        full_name: 'Driver',
        email: 'driver@test.com',
        password_hash: '',
        phone_number: '024',
        date_of_birth: '1990-01-01',
        license_number: 'LIC123',
        license_expiry: '2027-01-01',
        national_id: 'NID456',
      );

      expect(driver.isDriver, true);
      expect(driver.isPassenger, false);
    });

    test('isPassenger returns true when license_number is empty', () {
      final passenger = UserModel(
        id: '2',
        full_name: 'Passenger',
        email: 'pax@test.com',
        password_hash: '',
        phone_number: '024',
        date_of_birth: '',
        license_number: '',
        license_expiry: '',
        national_id: '',
      );

      expect(passenger.isDriver, false);
      expect(passenger.isPassenger, true);
    });

    test('copyWith preserves unchanged fields', () {
      final user = UserModel(
        id: '1',
        full_name: 'Original',
        email: 'orig@test.com',
        password_hash: '',
        phone_number: '024',
        date_of_birth: '',
        license_number: '',
        license_expiry: '',
        national_id: '',
      );

      final updated = user.copyWith(full_name: 'Updated');

      expect(updated.full_name, 'Updated');
      expect(updated.email, 'orig@test.com');
      expect(updated.id, '1');
    });

    test('toMap produces correct structure', () {
      final user = UserModel(
        id: '1',
        full_name: 'Test',
        email: 'test@test.com',
        password_hash: 'hash',
        phone_number: '024',
        date_of_birth: '1990-01-01',
        license_number: 'LIC',
        license_expiry: '2027',
        national_id: 'NID',
      );

      final map = user.toMap();

      expect(map['id'], '1');
      expect(map['full_name'], 'Test');
      expect(map['email'], 'test@test.com');
      expect(map['license_number'], 'LIC');
    });

    test('fromMap with driver_id fallback', () {
      final user1 = UserModel.fromMap({'id': 'abc'});
      expect(user1.id, 'abc');

      final user2 = UserModel.fromMap({'driver_id': 'xyz'});
      expect(user2.id, 'xyz');
      expect(user2.driverId, 'xyz');
    });
  });
}
