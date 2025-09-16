import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mobileapp/documents/document_list_screen.dart';

import 'driver_home_screen.dart';
import 'driver_profile_screen.dart';
import 'driver_profile_setting.dart';
import 'onboarding_screen.dart';
import 'sign_in.dart';
import 'sign_up.dart';
import 'wallet_screen.dart';
import 'welcome_screen.dart';
import '../vehicles/vehicle_list_screen.dart';

/// Define route constants to avoid typos
class Routes {
  static const onboarding = '/';
  static const welcome = '/welcome';
  static const signup = '/signup';
  static const signin = '/signin';
  static const home = '/home';
  static const wallet = '/wallet';
  static const profile = '/profile';
  static const profileSetting = '/profile_setting';
  static const vehicles = '/vehicles';
  static const documents = '/documents';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Safer token setup: will use dart-define if passed, else fallback
  const token = String.fromEnvironment(
    "ACCESS_TOKEN",
    defaultValue: "YOUR_MAPBOX_ACCESS_TOKEN", // <-- Replace with real token
  );

  MapboxOptions.setAccessToken(token);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driver App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.indigo,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      initialRoute: Routes.onboarding,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case Routes.onboarding:
            return MaterialPageRoute(builder: (_) => const OnboardingScreen());
          case Routes.welcome:
            return MaterialPageRoute(builder: (_) => const WelcomeScreen());
          case Routes.signup:
            return MaterialPageRoute(builder: (_) => const SignUpScreen());
          case Routes.signin:
            return MaterialPageRoute(builder: (_) => const SignInScreen());
          case Routes.home:
            return MaterialPageRoute(builder: (_) => const DriverHomeScreen());
          case Routes.wallet:
            return MaterialPageRoute(builder: (_) => const WalletScreen());
          case Routes.profile:
            final accessToken = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => DriverProfileScreen(accessToken: accessToken),
            );
          case Routes.profileSetting:
            return MaterialPageRoute(
              builder: (_) => const DriverProfileSetting(),
            );
          case Routes.vehicles:
            return MaterialPageRoute(builder: (_) => const VehicleListScreen());
          case Routes.documents:
            return MaterialPageRoute(
              builder: (_) => DocumentListScreen(accessToken: ''),
            );
          default:
            return MaterialPageRoute(builder: (_) => const OnboardingScreen());
        }
      },
    );
  }
}
