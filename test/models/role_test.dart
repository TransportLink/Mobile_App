import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/providers/user_role_provider.dart';
import 'package:mobileapp/core/model/user_model.dart';

void main() {
  group('UserRole enum', () {
    test('has three values', () {
      expect(UserRole.values.length, 3);
      expect(UserRole.values, contains(UserRole.driver));
      expect(UserRole.values, contains(UserRole.passenger));
      expect(UserRole.values, contains(UserRole.unknown));
    });
  });

  group('UserModel role inference', () {
    test('driver has non-empty license_number', () {
      final driver = UserModel(
        id: '1',
        full_name: 'Driver',
        email: 'drv@t.com',
        password_hash: '',
        phone_number: '024',
        date_of_birth: '1990-01-01',
        license_number: 'LIC123',
        license_expiry: '2027',
        national_id: 'NID456',
      );

      expect(driver.isDriver, true);
      expect(driver.isPassenger, false);
    });

    test('passenger has empty license_number', () {
      final pax = UserModel(
        id: '2',
        full_name: 'Passenger',
        email: 'pax@t.com',
        password_hash: '',
        phone_number: '024',
        date_of_birth: '',
        license_number: '',
        license_expiry: '',
        national_id: '',
      );

      expect(pax.isDriver, false);
      expect(pax.isPassenger, true);
    });

    test('fromMap with driver data infers driver', () {
      final user = UserModel.fromMap({
        'id': '1',
        'full_name': 'Test',
        'email': 'test@t.com',
        'license_number': 'LIC999',
      });

      expect(user.isDriver, true);
    });

    test('fromMap with no driver data infers passenger', () {
      final user = UserModel.fromMap({
        'id': '2',
        'full_name': 'Test',
        'email': 'test@t.com',
      });

      expect(user.isPassenger, true);
    });
  });

  group('UserRoleNotifier', () {
    test('initial state is unknown', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final notifier = UserRoleNotifier();

      expect(notifier.state, UserRole.unknown);
      expect(notifier.isUnknown, true);
      expect(notifier.isDriver, false);
      expect(notifier.isPassenger, false);
    });
  });
}
