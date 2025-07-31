import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mobileapp/driver_profile_setting.dart';

import 'driver_home_screen.dart';
import 'driver_profile_screen.dart';
import 'onboarding_screen.dart';
import 'sign_in.dart';
import 'sign_up.dart';
import 'wallet_screen.dart';
import 'welcome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Pass your access token to MapboxOptions so you can load a map
  const token = String.fromEnvironment("ACCESS_TOKEN");
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
      initialRoute: '/',
      routes: {
        '/': (context) => const OnboardingScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/signin': (context) => const SignInScreen(),
        '/home': (context) => const DriverHomeScreen(),
        '/wallet': (context) => const WalletScreen(),
        '/profile': (context) => const DriverProfileScreen(),
        '/profile_setting': (context) => const DriverProfileSetting(),
      },
    );
  }
}
