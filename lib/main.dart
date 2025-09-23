import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mobileapp/core/providers/current_driver_notifier.dart';
import 'package:mobileapp/core/theme/app_palette.dart';
import 'package:mobileapp/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:mobileapp/features/home/view/pages/auth_page.dart';
import 'package:mobileapp/features/home/view/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(authViewmodelProvider.notifier).initSharedPreferences();

  // Load .env file
  await dotenv.load(fileName: ".env");

  // Retrieve Mapbox access token from .env
  final mapboxToken =
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? 'YOUR_MAPBOX_ACCESS_TOKEN';

  if (mapboxToken == 'YOUR_MAPBOX_ACCESS_TOKEN') {
    // ignore: avoid_print
    print('Warning: Mapbox access token not set in .env file');
  }

  MapboxOptions.setAccessToken(mapboxToken);

  runApp(
    UncontrolledProviderScope(container: container, child: MyApp()),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentDriverProvider);

    return MaterialApp(
      theme: CustomTheme.lightThemeMode,
      home: currentUser == null ? const AuthPage() : HomePage(),
    );
  }
}

class CustomTheme {
  static final lightThemeMode = ThemeData.light().copyWith(
      scaffoldBackgroundColor: AppPalette.backgroundColor,
      appBarTheme: AppBarThemeData().copyWith(
        backgroundColor: AppPalette.backgroundColor,
        titleTextStyle: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w600, color: Colors.black, fontSize: 24),
      ),
      textTheme: ThemeData.light().textTheme.copyWith(
          bodyLarge: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
          bodyMedium: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
          bodySmall: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w400, color: Colors.black),
          labelMedium: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
          titleLarge: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
          titleMedium: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w400, color: Colors.black)));
}
