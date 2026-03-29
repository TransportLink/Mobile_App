import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/passenger/repository/passenger_repository.dart';

void main() {
  group('Result<T, E>', () {
    test('success result has data and isSuccess', () {
      final result = Result<String, String>.success('hello');
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.data, 'hello');
      expect(result.error, isNull);
    });

    test('failure result has error and isFailure', () {
      final result = Result<String, String>.failure('oops');
      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(result.error, 'oops');
      expect(result.data, isNull);
    });

    test('map converts success value', () {
      final result = Result<int, String>.success(42);
      final mapped = result.map((n) => n.toString());
      expect(mapped.isSuccess, true);
      expect(mapped.data, '42');
    });

    test('map propagates failure', () {
      final result = Result<int, String>.failure('error');
      final mapped = result.map((n) => n.toString());
      expect(mapped.isFailure, true);
      expect(mapped.error, 'error');
    });

    test('success with complex type', () {
      final result = Result<Map<String, int>, String>.success({'count': 5});
      expect(result.data!['count'], 5);
    });

    test('failure with empty error message', () {
      final result = Result<int, String>.failure('');
      expect(result.isFailure, true);
      expect(result.error, '');
    });
  });
}
