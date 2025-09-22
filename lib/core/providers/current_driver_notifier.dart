import 'package:mobileapp/core/model/driver_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_driver_notifier.g.dart';

@Riverpod(keepAlive: true)
class CurrentDriverNotifier extends _$CurrentDriverNotifier {
  @override
  DriverModel? build() {
    return null;
  }

  void addCurrentDriver(DriverModel driver) {
    state = driver;
  }

  void clearCurrentDriver() {
    state = null;
  }
}
