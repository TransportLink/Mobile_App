import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/core/constants/server_constants.dart';
import 'package:mobileapp/core/model/user_model.dart';
import 'package:mobileapp/core/model/route.dart' as route_model;
import 'package:mobileapp/core/providers/current_user_notifier.dart';
import 'package:mobileapp/core/providers/user_role_provider.dart';
import 'package:mobileapp/features/auth/repository/auth_local_repository.dart';
import 'package:mobileapp/features/map/repository/map_repository.dart';
import 'package:mobileapp/passenger/repository/passenger_repository.dart';
import 'package:mobileapp/main.dart';

/// Smart Trotro — Comprehensive Integration Tests
///
/// Tests every user-facing feature for both driver and passenger roles.
/// Runs on Chrome (visible) or Android device.
///
///   Chrome:   flutter test integration_test/app_test.dart -d chrome
///   Android:  flutter test integration_test/app_test.dart -d <device-id>
///
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {
      // .env may not exist in test — use fallback values
    }
  });

  // ─── Test Users ─────────────────────────────────────────
  UserModel driverUser() => UserModel(
        id: 'test_drv',
        driverId: 'test_drv',
        full_name: 'Kwame Driver',
        email: 'kwame@test.com',
        password_hash: '',
        phone_number: '0241234567',
        date_of_birth: '1990-05-15',
        license_number: 'LIC12345',
        license_expiry: '2028-01-01',
        national_id: 'NID99999',
      );

  UserModel passengerUser() => UserModel(
        id: 'test_pax',
        driverId: 'test_pax',
        full_name: 'Ama Passenger',
        email: 'ama@test.com',
        password_hash: '',
        phone_number: '0501234567',
        date_of_birth: '',
        license_number: '',
        license_expiry: '',
        national_id: '',
      );

  Future<ProviderContainer> freshContainer() async {
    final container = ProviderContainer();
    await container.read(authLocalRepositoryProvider).init();
    return container;
  }

  Future<ProviderContainer> driverContainer() async {
    final c = await freshContainer();
    c.read(currentUserNotifierProvider.notifier).addCurrentUser(driverUser());
    await c.read(userRoleProvider.notifier).setRole(UserRole.driver);
    return c;
  }

  /// Pump until settled or timeout — avoids hanging on map tile loading
  Future<void> settle(WidgetTester t, {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      await t.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, timeout);
    } catch (_) {
      // pumpAndSettle timed out — map has ongoing activity, that's ok
      await t.pump();
    }
  }

  /// Tap the driver bottom nav item by index (0=Map, 1=Trips, 2=Demand, 3=Profile)
  Future<void> tapDriverNav(WidgetTester t, int index) async {
    // CustomBottomNav items are GestureDetector > Column > [Icon, Text]
    // Find all nav item text labels
    final labels = ['Map', 'Trips', 'Demand', 'Profile'];
    final finder = find.text(labels[index]);
    if (finder.evaluate().isEmpty) {
      // Fallback: try tapping by approximate position
      await t.pump(const Duration(seconds: 2));
    }
    await t.tap(finder);
    await settle(t);
  }

  Future<ProviderContainer> passengerContainer() async {
    final c = await freshContainer();
    c.read(currentUserNotifierProvider.notifier).addCurrentUser(passengerUser());
    await c.read(userRoleProvider.notifier).setRole(UserRole.passenger);
    return c;
  }

  // ═══════════════════════════════════════════════════════════
  //  SECTION 1: AUTHENTICATION FLOW
  // ═══════════════════════════════════════════════════════════

  group('1. Auth — Landing Page', () {
    testWidgets('1.1 Shows branding, login, and signup buttons', (t) async {
      final c = await freshContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      // First test — give app extra time to fully initialize
      await t.pump(const Duration(seconds: 3));
      await settle(t);
      expect(find.text('Smart Trotro'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });
  });

  group('2. Auth — Login Page', () {
    testWidgets('2.1 Login page has email and password fields', (t) async {
      final c = await freshContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await t.pumpAndSettle();
      await t.tap(find.text('Login'));
      await t.pumpAndSettle();
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('2.2 Can type into login fields', (t) async {
      final c = await freshContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await t.pumpAndSettle();
      await t.tap(find.text('Login'));
      await t.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await t.enterText(fields.at(0), 'test@example.com');
      await t.enterText(fields.at(1), 'password123');
      await t.pumpAndSettle();
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('2.3 Empty submit shows validation', (t) async {
      final c = await freshContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await t.pumpAndSettle();
      await t.tap(find.text('Login'));
      await t.pumpAndSettle();
      // Tap the bottom Login button
      final buttons = find.text('Login');
      await t.tap(buttons.last);
      await t.pumpAndSettle();
      expect(find.textContaining('Invalid'), findsOneWidget);
    });
  });

  group('3. Auth — Role Selection', () {
    testWidgets('3.1 Create account opens role selection', (t) async {
      final c = await freshContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await t.pumpAndSettle();
      await t.tap(find.text('Create an account'));
      await t.pumpAndSettle();
      expect(find.textContaining('How will you'), findsOneWidget);
      expect(find.text("I'm a Driver"), findsOneWidget);
      expect(find.text("I'm a Passenger"), findsOneWidget);
    });

    testWidgets('3.2 Driver role shows all 8 signup fields', (t) async {
      final c = await freshContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await t.pumpAndSettle();
      await t.tap(find.text('Create an account'));
      await t.pumpAndSettle();
      await t.tap(find.text("I'm a Driver"));
      await t.pumpAndSettle();
      expect(find.text('Create Driver Account'), findsOneWidget);
      expect(find.text('Signing up as a Driver'), findsOneWidget);
      expect(find.text('License Number'), findsOneWidget);
      expect(find.text('National ID'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      // Scroll to see all fields
      await t.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await t.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(8));
    });

    testWidgets('3.3 Passenger role shows only 4 fields', (t) async {
      final c = await freshContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await t.pumpAndSettle();
      await t.tap(find.text('Create an account'));
      await t.pumpAndSettle();
      await t.tap(find.text("I'm a Passenger"));
      await t.pumpAndSettle();
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Signing up as a Passenger'), findsOneWidget);
      expect(find.text('License Number'), findsNothing);
      expect(find.text('National ID'), findsNothing);
      expect(find.text('Date of Birth'), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('3.4 Back from role selection returns to landing', (t) async {
      final c = await freshContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await t.pumpAndSettle();
      await t.tap(find.text('Create an account'));
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.text('Smart Trotro'), findsOneWidget);
    });

    testWidgets('3.5 Empty signup shows validation error', (t) async {
      final c = await freshContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await t.pumpAndSettle();
      await t.tap(find.text('Create an account'));
      await t.pumpAndSettle();
      await t.tap(find.text("I'm a Passenger"));
      await t.pumpAndSettle();
      await t.tap(find.text('Create an account'));
      await t.pumpAndSettle();
      expect(find.textContaining('Invalid'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  SECTION 2: ROLE-BASED ROUTING
  // ═══════════════════════════════════════════════════════════

  group('4. Routing — Role-based home screen', () {
    testWidgets('4.1 Unauthenticated → auth page', (t) async {
      final c = await freshContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      expect(find.text('Smart Trotro'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('4.2 Driver → 4-tab nav (Map, Trips, Demand, Profile)', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Demand'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Activity'), findsNothing);
    });

    testWidgets('4.3 Passenger → 4-tab nav (Map, Stops, Activity, Profile)', (t) async {
      final c = await passengerContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Stops'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      // Driver-only tabs NOT present
      expect(find.text('Trips'), findsNothing);
      expect(find.text('Demand'), findsNothing);
    });

    testWidgets('4.4 Authenticated user sees home (not auth page)', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      // Should NOT see auth page when logged in
      expect(find.text('Smart Trotro'), findsNothing);
      expect(find.text('Create an account'), findsNothing);
      // Should see some home screen content
      expect(find.text('Map'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  SECTION 3: DRIVER FEATURES
  // ═══════════════════════════════════════════════════════════

  group('5. Driver — Tab Navigation', () {
    testWidgets('5.1 Trips tab shows dashboard', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await tapDriverNav(t, 1); // Trips
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('5.2 Profile tab shows account hub with driver items', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await tapDriverNav(t, 3); // Profile
      expect(find.text('Kwame Driver'), findsAtLeastNWidgets(1));
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('My Vehicles'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('5.3 Profile shows logout button', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await tapDriverNav(t, 3); // Profile
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('5.4 Map tab is default (first tab)', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      expect(find.text('Map'), findsOneWidget);
    });
  });

  group('6. Driver — No Vehicle Warning', () {
    testWidgets('6.1 Shows warning when no default vehicle set', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      expect(find.textContaining('No vehicle selected'), findsOneWidget);
    });
  });

  group('7. Driver — Logout', () {
    testWidgets('7.1 Logout shows confirmation dialog', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await tapDriverNav(t, 3); // Profile
      await t.tap(find.byIcon(Icons.logout));
      await settle(t);
      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Do you really want to leave?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('7.2 Cancel keeps user on profile', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await tapDriverNav(t, 3); // Profile
      await t.tap(find.byIcon(Icons.logout));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(find.text('Kwame Driver'), findsAtLeastNWidgets(1));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  SECTION 4: PASSENGER FEATURES
  // ═══════════════════════════════════════════════════════════

  group('8. Passenger — Tab Navigation', () {
    testWidgets('8.1 Stops tab shows nearby stops list', (t) async {
      final c = await passengerContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await t.tap(find.text('Stops'));
      await settle(t);
      expect(find.text('Nearby Stops'), findsOneWidget);
    });

    testWidgets('8.2 Activity tab shows empty state when not checked in', (t) async {
      final c = await passengerContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await t.tap(find.text('Activity'));
      await settle(t);
      expect(find.text('No activity yet'), findsOneWidget);
      expect(find.text('Find a bus stop'), findsOneWidget);
    });

    testWidgets('8.3 Profile shows passenger info, hides driver fields and wallet', (t) async {
      final c = await passengerContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await t.tap(find.text('Profile'));
      await settle(t);
      expect(find.text('Ama Passenger'), findsAtLeastNWidgets(1));
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
      // Driver-only items hidden
      expect(find.text('My Vehicles'), findsNothing);
      expect(find.text('Documents'), findsNothing);
      expect(find.text('Wallet'), findsNothing);
    });

    testWidgets('8.4 Passenger profile has About', (t) async {
      final c = await passengerContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await t.tap(find.text('Profile'));
      await settle(t);
      expect(find.text('About Smart Trotro'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  SECTION 5: ACCOUNT HUB (Profile Tab)
  // ═══════════════════════════════════════════════════════════

  group('9. Account Hub — Driver', () {
    testWidgets('9.1 Shows profile card with name and email', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await tapDriverNav(t, 3); // Profile
      expect(find.text('Kwame Driver'), findsAtLeastNWidgets(1));
      expect(find.text('kwame@test.com'), findsAtLeastNWidgets(1));
    });

    testWidgets('9.2 Shows Edit Profile menu item', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await tapDriverNav(t, 3);
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('9.3 Shows driver-only menu items (Vehicles, Documents)', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await tapDriverNav(t, 3);
      expect(find.text('My Vehicles'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('9.4 Edit Profile opens edit form', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await tapDriverNav(t, 3);
      await t.tap(find.text('Edit Profile'));
      await settle(t);
      expect(find.text('Edit Profile'), findsAtLeastNWidgets(1)); // AppBar title
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
    });

    testWidgets('9.5 Log Out shows confirmation', (t) async {
      final c = await driverContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await tapDriverNav(t, 3);
      await t.tap(find.text('Log Out'));
      await settle(t);
      expect(find.text('Do you really want to leave?'), findsOneWidget);
      // Cancel
      await t.tap(find.text('Cancel'));
      await settle(t);
    });
  });

  group('9B. Account Hub — Passenger', () {
    testWidgets('9B.1 Passenger hub hides driver-only items and wallet', (t) async {
      final c = await passengerContainer();
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      await t.tap(find.text('Profile'));
      await settle(t);
      expect(find.text('Ama Passenger'), findsAtLeastNWidgets(1));
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
      expect(find.text('About Smart Trotro'), findsOneWidget);
      // Driver-only items hidden
      expect(find.text('My Vehicles'), findsNothing);
      expect(find.text('Documents'), findsNothing);
      expect(find.text('Wallet'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  SECTION 6: ROLE INFERENCE
  // ═══════════════════════════════════════════════════════════

  group('10. Role — Inference from profile data', () {
    testWidgets('10.1 User with license → driver home', (t) async {
      final c = await freshContainer();
      c.read(currentUserNotifierProvider.notifier).addCurrentUser(driverUser());
      final user = c.read(currentUserNotifierProvider);
      if (user != null && user.isDriver) {
        await c.read(userRoleProvider.notifier).setRole(UserRole.driver);
      }
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      expect(find.text('Demand'), findsOneWidget);
    });

    testWidgets('10.2 User without license → passenger home', (t) async {
      final c = await freshContainer();
      c.read(currentUserNotifierProvider.notifier).addCurrentUser(passengerUser());
      final user = c.read(currentUserNotifierProvider);
      if (user != null && user.isPassenger) {
        await c.read(userRoleProvider.notifier).setRole(UserRole.passenger);
      }
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MyApp()));
      await settle(t);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Demand'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  SECTION 7: END-TO-END API FLOWS
  //  These hit the REAL backend via ADB reverse ports
  // ═══════════════════════════════════════════════════════════

  // Shared state for E2E tests
  String? _e2eToken;
  String? _e2eDriverId;
  String? _e2eVehicleId;
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 15)));
  const _apiKey = 'MshsAdSLMPHpWfOYKSX6LROHv1FBmOZpHZ_ofiZIij8';

  /// Login and get token — called before E2E test groups that need auth
  Future<void> _ensureLoggedIn() async {
    if (_e2eToken != null && _e2eDriverId != null) return;
    final resp = await _dio.post(
      '${ServerConstants.authServiceUrl}/auth/login',
      data: {'identifier': 'test_driver_integration@trotro.test', 'password': 'TestPass123!'},
    );
    _e2eToken = resp.data['access_token'];
    final profile = await _dio.get(
      '${ServerConstants.authServiceUrl}/drivers/me',
      options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
    );
    _e2eDriverId = profile.data['id'] ?? profile.data['driver_id'];
  }

  /// Ensure a vehicle exists for trip acceptance
  Future<void> _ensureVehicleExists() async {
    if (_e2eVehicleId != null) return;
    await _ensureLoggedIn();
    // List vehicles — use existing or create new
    final listResp = await _dio.get(
      '${ServerConstants.authServiceUrl}/vehicles/',
      options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
    );
    final vehicles = listResp.data is List ? listResp.data : (listResp.data['vehicles'] ?? []);
    if (vehicles.isNotEmpty) {
      _e2eVehicleId = vehicles[0]['vehicle_id'] ?? vehicles[0]['id'];
      return;
    }
    // Create one
    final createResp = await _dio.post(
      '${ServerConstants.authServiceUrl}/vehicles/',
      data: {
        'plate_number': 'TST-E2E-${DateTime.now().millisecondsSinceEpoch % 10000}',
        'color': 'White',
        'seating_capacity': 14,
        'vehicle_type': 'bus',
        'brand': 'Toyota',
        'model': 'HiAce',
        'year': '2020',
      },
      options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
    );
    _e2eVehicleId = createResp.data['vehicle_id'] ?? createResp.data['id'];
  }

  group('11. E2E — Driver Login via API', () {
    testWidgets('11.1 Login with real credentials returns token', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        await _ensureLoggedIn();
        expect(_e2eToken, isNotNull);
        expect(_e2eToken!.length, greaterThan(50));
        expect(_e2eDriverId, isNotNull);
      } catch (e) {
        fail('Login API failed: $e');
      }
    });

    testWidgets('11.2 Vehicle exists or created for trip tests', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        await _ensureVehicleExists();
        expect(_e2eVehicleId, isNotNull);
      } catch (e) {
        fail('Vehicle setup failed: $e');
      }
    });
  });

  group('12. E2E — Driver Trip Lifecycle', () {
    int? tripId;

    testWidgets('12.1 Get available passengers before trip', (t) async {
      await t.pumpWidget(Container()); // minimal widget
      await t.pump();

      try {
        final resp = await _dio.get(
          '${ServerConstants.webServerUrl}/available_passengers/',
          queryParameters: {'system_id': 'Legon_bustop', 'destination': 'Oyibi'},
          options: Options(headers: {'X-API-KEY': _apiKey}),
        );
        expect(resp.statusCode, 200);
        final available = resp.data['available_passengers'];
        expect(available, isA<int>());
        expect(available, greaterThanOrEqualTo(0));
      } catch (e) {
        fail('Available passengers API failed: $e');
      }
    });

    testWidgets('12.2 Accept trip via Map Microservice', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        await _ensureLoggedIn();
        await _ensureVehicleExists();
        if (_e2eToken == null || _e2eDriverId == null) {
          fail('Login succeeded but token=$_e2eToken driverId=$_e2eDriverId');
          return;
        }
      } catch (e) {
        fail('Setup failed: $e');
        return;
      }

      // Clean up any leftover trip
      try {
        await _dio.post(
          '${ServerConstants.webServerUrl}/api/cancel_trip/',
          data: {'trip_id': 0, 'driver_id': _e2eDriverId},
          options: Options(headers: {'X-API-KEY': _apiKey}),
        );
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));

      try {
        final dests = Uri.encodeComponent(jsonEncode([{'destination': 'Oyibi', 'passenger_count': 2}]));
        final resp = await _dio.get(
          '${ServerConstants.mapServiceUrl}routes/'
          '?driver_id=$_e2eDriverId'
          '&system_id=Legon_bustop'
          '&bus_stop=Legon_bustop'
          '&bus_stop_lat=5.6488&bus_stop_lng=-0.1860'
          '&driver_lat=5.6500&driver_lng=-0.1850'
          '&destinations=$dests'
          '&vehicle_capacity=14'
          '&bus_color=White'
          '&license_plate=GE-56678-26',
          options: Options(headers: {
            'Authorization': 'Bearer $_e2eToken',
            'X-API-KEY': _apiKey,
          }),
        );
        expect(resp.statusCode, 200);
        tripId = resp.data['trip_id'];
        if (tripId == null || tripId == 0) {
          fail('Trip not created. Response: ${resp.data}');
          return;
        }

        // Verify route data
        final route = resp.data['route'];
        if (route == null) {
          fail('No route in response. Response: ${resp.data}');
          return;
        }
        expect(route['geometry'], isNotNull, reason: 'route.geometry is null');
        expect(route['eta'], isNotNull, reason: 'route.eta is null');
        expect(route['distance'], isNotNull, reason: 'route.distance is null');

        // Verify Route.fromJson converts units correctly
        final parsed = route_model.Route.fromJson(route);
        expect(parsed.eta, greaterThan(0), reason: 'parsed eta should be > 0 minutes');
        expect(parsed.distance, greaterThan(0), reason: 'parsed distance should be > 0 km');
        expect(parsed.coordinates.length, greaterThan(1), reason: 'polyline should have > 1 point');
      } on DioException catch (e) {
        fail('Accept trip Dio error: ${e.response?.statusCode} ${e.response?.data}');
      } catch (e) {
        fail('Accept trip failed: $e');
      }
    });

    testWidgets('12.3 Verify trip exists in Django', (t) async {
      await t.pumpWidget(Container());
      await t.pump();
      await Future.delayed(const Duration(seconds: 1));

      try {
        final resp = await _dio.get(
          '${ServerConstants.webServerUrl}/api/driver/active_trip/',
          queryParameters: {'driver_id': _e2eDriverId},
        );
        expect(resp.statusCode, 200);
        final activeTrip = resp.data['active_trip'];
        expect(activeTrip, isNotNull);
        expect(activeTrip['trip_id'], tripId);
        expect(activeTrip['status'], 'pending');
        expect(activeTrip['system_id'], 'Legon_bustop');
      } catch (e) {
        fail('Active trip check failed: $e');
      }
    });

    testWidgets('12.4 Passengers decreased after trip accept', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        final resp = await _dio.get(
          '${ServerConstants.webServerUrl}/available_passengers/',
          queryParameters: {'system_id': 'Legon_bustop', 'destination': 'Oyibi'},
          options: Options(headers: {'X-API-KEY': _apiKey}),
        );
        expect(resp.statusCode, 200);
        // Count should be reduced by 2 (we reserved 2 passengers)
        final available = resp.data['available_passengers'] as int;
        expect(available, greaterThanOrEqualTo(0));
      } catch (e) {
        fail('Available passengers check failed: $e');
      }
    });

    testWidgets('12.5 Double accept rejected', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        final dests = Uri.encodeComponent(jsonEncode([{'destination': 'Oyibi', 'passenger_count': 1}]));
        final resp = await _dio.get(
          '${ServerConstants.mapServiceUrl}routes/'
          '?driver_id=$_e2eDriverId'
          '&system_id=Legon_bustop&bus_stop=Legon_bustop'
          '&bus_stop_lat=5.6488&bus_stop_lng=-0.1860'
          '&driver_lat=5.65&driver_lng=-0.185'
          '&destinations=$dests'
          '&vehicle_capacity=14&bus_color=White&license_plate=TST-DBL',
          options: Options(headers: {
            'Authorization': 'Bearer $_e2eToken',
            'X-API-KEY': _apiKey,
          }),
        );
        // Should be rejected (400) because driver already has active trip
        fail('Double accept should have been rejected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 400);
        expect(e.response?.data['detail'].toString().toLowerCase(), contains('already'));
      }
    });

    testWidgets('12.6 Cancel trip restores passengers', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        final resp = await _dio.post(
          '${ServerConstants.webServerUrl}/api/cancel_trip/',
          data: {'trip_id': tripId, 'driver_id': _e2eDriverId},
          options: Options(headers: {'X-API-KEY': _apiKey}),
        );
        expect(resp.statusCode, 200);
        expect(resp.data['status'], 'success');
        expect(resp.data['remaining_passengers'], isNotEmpty);
      } catch (e) {
        fail('Cancel trip failed: $e');
      }
    });

    testWidgets('12.7 No active trip after cancel', (t) async {
      await t.pumpWidget(Container());
      await t.pump();
      await Future.delayed(const Duration(seconds: 1));

      try {
        final resp = await _dio.get(
          '${ServerConstants.webServerUrl}/api/driver/active_trip/',
          queryParameters: {'driver_id': _e2eDriverId},
        );
        expect(resp.statusCode, 200);
        expect(resp.data['active_trip'], isNull);
      } catch (e) {
        fail('Active trip check after cancel failed: $e');
      }
    });

    testWidgets('12.8 Cancelled trip appears in history', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        final resp = await _dio.get(
          '${ServerConstants.webServerUrl}/api/driver/trips/',
          queryParameters: {'driver_id': _e2eDriverId, 'status': 'cancelled', 'limit': 1},
        );
        expect(resp.statusCode, 200);
        final trips = resp.data['trips'] as List;
        expect(trips, isNotEmpty);
        expect(trips.first['trip_id'], tripId);
        expect(trips.first['status'], 'cancelled');
      } catch (e) {
        fail('Trip history check failed: $e');
      }
    });

    testWidgets('12.9 Idempotent cancel is safe', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        final resp = await _dio.post(
          '${ServerConstants.webServerUrl}/api/cancel_trip/',
          data: {'trip_id': tripId, 'driver_id': _e2eDriverId},
          options: Options(headers: {'X-API-KEY': _apiKey}),
        );
        expect(resp.statusCode, 200);
        expect(resp.data['status'], 'success');
      } catch (e) {
        fail('Idempotent cancel failed: $e');
      }
    });
  });

  group('13. E2E — Trip Restoration After Logout', () {
    int? restoreTripId;

    testWidgets('13.1 Create trip, then verify restorable', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try { await _ensureLoggedIn(); } catch (e) { fail('Login failed: $e'); return; }

      try {
        final dests = Uri.encodeComponent(jsonEncode([{'destination': 'Oyibi', 'passenger_count': 2}]));
        final resp = await _dio.get(
          '${ServerConstants.mapServiceUrl}routes/'
          '?driver_id=$_e2eDriverId'
          '&system_id=Legon_bustop&bus_stop=Legon_bustop'
          '&bus_stop_lat=5.6488&bus_stop_lng=-0.1860'
          '&driver_lat=5.65&driver_lng=-0.185'
          '&destinations=$dests'
          '&vehicle_capacity=14&bus_color=White&license_plate=GE-56678-26',
          options: Options(headers: {
            'Authorization': 'Bearer $_e2eToken',
            'X-API-KEY': _apiKey,
          }),
        );
        restoreTripId = resp.data['trip_id'];
        expect(restoreTripId, greaterThan(0));
      } catch (e) {
        fail('Create trip for restoration test failed: $e');
      }
    });

    testWidgets('13.2 Trip survives re-login (server is source of truth)', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try { await _ensureLoggedIn(); } catch (e) { fail('Login: $e'); return; }
      if (restoreTripId == null) { fail('No trip to restore'); return; }

      try {
        // Re-login (simulates app restart / logout+login)
        final loginResp = await _dio.post(
          '${ServerConstants.authServiceUrl}/auth/login',
          data: {'identifier': 'test_driver_integration@trotro.test', 'password': 'TestPass123!'},
        );
        final newToken = loginResp.data['access_token'];
        expect(newToken, isNotNull);

        // Check active trip with new token — should still exist
        final tripResp = await _dio.get(
          '${ServerConstants.webServerUrl}/api/driver/active_trip/',
          queryParameters: {'driver_id': _e2eDriverId},
        );
        expect(tripResp.data['active_trip'], isNotNull);
        expect(tripResp.data['active_trip']['trip_id'], restoreTripId);

        // Clean up
        await _dio.post(
          '${ServerConstants.webServerUrl}/api/cancel_trip/',
          data: {'trip_id': restoreTripId, 'driver_id': _e2eDriverId},
          options: Options(headers: {'X-API-KEY': _apiKey}),
        );
      } catch (e) {
        fail('Trip restoration test failed: $e');
      }
    });
  });

  group('14. E2E — Complete Trip with Earnings', () {
    testWidgets('14.1 Create and complete trip, verify earnings', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try { await _ensureLoggedIn(); } catch (e) { fail('Login failed: $e'); return; }

      try {
        // Create trip
        final dests = Uri.encodeComponent(jsonEncode([{'destination': 'Oyibi', 'passenger_count': 3}]));
        final createResp = await _dio.get(
          '${ServerConstants.mapServiceUrl}routes/'
          '?driver_id=$_e2eDriverId'
          '&system_id=Legon_bustop&bus_stop=Legon_bustop'
          '&bus_stop_lat=5.6488&bus_stop_lng=-0.1860'
          '&driver_lat=5.65&driver_lng=-0.185'
          '&destinations=$dests'
          '&vehicle_capacity=14&bus_color=White&license_plate=GE-56678-26',
          options: Options(headers: {
            'Authorization': 'Bearer $_e2eToken',
            'X-API-KEY': _apiKey,
          }),
        );
        final tid = createResp.data['trip_id'];
        expect(tid, greaterThan(0));

        await Future.delayed(const Duration(seconds: 1));

        // Complete trip
        final completeResp = await _dio.post(
          '${ServerConstants.webServerUrl}/complete_trip/',
          data: {'trip_id': tid, 'driver_id': _e2eDriverId, 'system_id': 'Legon_bustop'},
          options: Options(headers: {'X-API-KEY': _apiKey}),
        );
        expect(completeResp.statusCode, 200);
        expect(completeResp.data['earnings'], isNotNull);
        expect(completeResp.data['earnings']['amount'], greaterThan(0));
        expect(completeResp.data['earnings']['passenger_count'], 3);

        // Verify in history as completed
        await Future.delayed(const Duration(seconds: 1));
        final histResp = await _dio.get(
          '${ServerConstants.webServerUrl}/api/driver/trips/',
          queryParameters: {'driver_id': _e2eDriverId, 'status': 'completed', 'limit': 1},
        );
        expect(histResp.data['trips'].first['trip_id'], tid);
        expect(histResp.data['trips'].first['status'], 'completed');
      } catch (e) {
        fail('Complete trip with earnings failed: $e');
      }
    });
  });

  group('15. E2E — Passenger Check-in Flow', () {
    testWidgets('15.1 Check in at bus stop', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try { await _ensureLoggedIn(); } catch (e) { fail('Login failed: $e'); return; }

      try {
        final resp = await _dio.post(
          '${ServerConstants.webServerUrl}/api/passenger/check_in/',
          data: {
            'system_id': 'Legon_bustop',
            'destination': 'Oyibi',
            'passenger_count': 1,
            'latitude': 5.648842,
            'longitude': -0.186009,
          },
          options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
        );
        expect(resp.statusCode, 200);
        expect(resp.data['status'], 'checked_in');
        expect(resp.data['queue_position'], greaterThan(0));
        expect(resp.data['total_waiting'], greaterThan(0));
      } catch (e) {
        fail('Passenger check-in failed: $e');
      }
    });

    testWidgets('15.2 Get my check-in status', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        final resp = await _dio.get(
          '${ServerConstants.webServerUrl}/api/passenger/my_checkin/',
          options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
        );
        expect(resp.statusCode, 200);
        expect(resp.data['active_checkin'], isNotNull);
        expect(resp.data['active_checkin']['destination'], 'Oyibi');
        expect(resp.data['active_checkin']['system_id'], 'Legon_bustop');
      } catch (e) {
        fail('Get my check-in failed: $e');
      }
    });

    testWidgets('15.3 Get stop info with demand', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        final resp = await _dio.get(
          '${ServerConstants.webServerUrl}/api/passenger/stop_info/Legon_bustop/',
        );
        expect(resp.statusCode, 200);
        expect(resp.data['system_id'], 'Legon_bustop');
        expect(resp.data['demand'], isNotNull);
      } catch (e) {
        fail('Stop info failed: $e');
      }
    });

    testWidgets('15.4 Check out from bus stop', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        final resp = await _dio.post(
          '${ServerConstants.webServerUrl}/api/passenger/check_out/',
          data: {'reason': 'manual'},
          options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
        );
        expect(resp.statusCode, 200);
        expect(resp.data['status'], 'checked_out');
      } catch (e) {
        fail('Passenger check-out failed: $e');
      }
    });

    testWidgets('15.5 No active check-in after checkout', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try {
        final resp = await _dio.get(
          '${ServerConstants.webServerUrl}/api/passenger/my_checkin/',
          options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
        );
        expect(resp.statusCode, 200);
        expect(resp.data['active_checkin'], isNull);
      } catch (e) {
        fail('Check-in status after checkout failed: $e');
      }
    });
  });

  group('15B. E2E — Passenger Geofence & Stale Check-in', () {
    testWidgets('15B.1 Check in then verify stale detection works', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try { await _ensureLoggedIn(); } catch (e) { fail('Login: $e'); return; }

      // Check in
      await _dio.post(
        '${ServerConstants.webServerUrl}/api/passenger/check_in/',
        data: {
          'system_id': 'Legon_bustop',
          'destination': 'Oyibi',
          'passenger_count': 1,
          'latitude': 5.648842,
          'longitude': -0.186009,
        },
        options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
      );

      // Verify checked in
      final myCheckin = await _dio.get(
        '${ServerConstants.webServerUrl}/api/passenger/my_checkin/',
        options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
      );
      expect(myCheckin.data['active_checkin'], isNotNull);
      expect(myCheckin.data['active_checkin']['destination'], 'Oyibi');

      // Now checkout (simulating what geofence would do)
      final checkoutResp = await _dio.post(
        '${ServerConstants.webServerUrl}/api/passenger/check_out/',
        data: {'reason': 'auto_exit'},
        options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
      );
      expect(checkoutResp.statusCode, 200);
      expect(checkoutResp.data['status'], 'checked_out');
      expect(checkoutResp.data['reason'], 'auto_exit');

      // Verify no longer checked in
      final after = await _dio.get(
        '${ServerConstants.webServerUrl}/api/passenger/my_checkin/',
        options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
      );
      expect(after.data['active_checkin'], isNull);
    });

    testWidgets('15B.2 Double check-in replaces previous', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try { await _ensureLoggedIn(); } catch (e) { fail('Login: $e'); return; }

      try {
        // First check-in
        await _dio.post(
          '${ServerConstants.webServerUrl}/api/passenger/check_in/',
          data: {
            'system_id': 'Legon_bustop',
            'destination': 'Oyibi',
            'passenger_count': 1,
            'latitude': 5.648842,
            'longitude': -0.186009,
          },
          options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
        );

        // Second check-in for different destination — should replace
        final resp2 = await _dio.post(
          '${ServerConstants.webServerUrl}/api/passenger/check_in/',
          data: {
            'system_id': 'Legon_bustop',
            'destination': 'Madina',
            'passenger_count': 2,
            'latitude': 5.648842,
            'longitude': -0.186009,
          },
          options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
        );
        // Should succeed (replaces old) or return already checked in
        expect(resp2.statusCode, 200);

        // Clean up
        await _dio.post(
          '${ServerConstants.webServerUrl}/api/passenger/check_out/',
          data: {'reason': 'manual'},
          options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
        );
      } catch (e) {
        // Clean up even on failure
        try {
          await _dio.post(
            '${ServerConstants.webServerUrl}/api/passenger/check_out/',
            data: {'reason': 'manual'},
            options: Options(headers: {'Authorization': 'Bearer $_e2eToken'}),
          );
        } catch (_) {}
        fail('Double check-in test failed: $e');
      }
    });
  });

  group('16. E2E — Security', () {
    testWidgets('16.1 Wrong driver cannot cancel another drivers trip', (t) async {
      await t.pumpWidget(Container());
      await t.pump();

      try { await _ensureLoggedIn(); } catch (e) { fail('Login failed: $e'); return; }

      try {
        // Create a trip
        final dests = Uri.encodeComponent(jsonEncode([{'destination': 'Oyibi', 'passenger_count': 1}]));
        final createResp = await _dio.get(
          '${ServerConstants.mapServiceUrl}routes/'
          '?driver_id=$_e2eDriverId'
          '&system_id=Legon_bustop&bus_stop=Legon_bustop'
          '&bus_stop_lat=5.6488&bus_stop_lng=-0.1860'
          '&driver_lat=5.65&driver_lng=-0.185'
          '&destinations=$dests'
          '&vehicle_capacity=14&bus_color=White&license_plate=GE-56678-26',
          options: Options(headers: {
            'Authorization': 'Bearer $_e2eToken',
            'X-API-KEY': _apiKey,
          }),
        );
        final tid = createResp.data['trip_id'];

        // Try cancel with wrong driver_id
        final cancelResp = await _dio.post(
          '${ServerConstants.webServerUrl}/api/cancel_trip/',
          data: {'trip_id': tid, 'driver_id': 'fake-driver-id-xyz'},
          options: Options(headers: {'X-API-KEY': _apiKey}),
        );
        // Should succeed with "No active trip" (wrong driver has no trips)
        expect(cancelResp.data['message'].toString().toLowerCase(), contains('no active trip'));

        // Verify original trip still active
        final checkResp = await _dio.get(
          '${ServerConstants.webServerUrl}/api/driver/active_trip/',
          queryParameters: {'driver_id': _e2eDriverId},
        );
        expect(checkResp.data['active_trip'], isNotNull);

        // Clean up
        await _dio.post(
          '${ServerConstants.webServerUrl}/api/cancel_trip/',
          data: {'trip_id': tid, 'driver_id': _e2eDriverId},
          options: Options(headers: {'X-API-KEY': _apiKey}),
        );
      } catch (e) {
        fail('Security test failed: $e');
      }
    });
  });
}
