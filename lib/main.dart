import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobileapp/core/providers/current_user_notifier.dart';
import 'package:mobileapp/core/providers/user_role_provider.dart';
import 'package:mobileapp/core/theme/app_palette.dart';
import 'package:mobileapp/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:mobileapp/features/home/view/pages/auth_page.dart';
import 'package:mobileapp/main_screen.dart';
import 'package:mobileapp/passenger/view/passenger_home_page.dart';

import 'package:mobileapp/core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(authViewmodelProvider.notifier).initSharedPreferences();

  // Load .env file
  await dotenv.load(fileName: ".env");

  // Initialize notifications
  await NotificationService().initialize();
  await NotificationService().scheduleDailySummary();

  runApp(
    UncontrolledProviderScope(container: container, child: MyApp()),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserNotifierProvider);

    final role = ref.watch(userRoleProvider);

    Widget home;
    if (currentUser == null) {
      home = const AuthPage();
    } else if (role == UserRole.passenger) {
      home = const PassengerHomePage();
    } else {
      home = const MainScreen(); // driver + unknown defaults to driver (4-tab nav)
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CustomTheme.lightThemeMode,
      home: home,
    );
  }
}

class CustomTheme {
  static final lightThemeMode = ThemeData.light().copyWith(
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey[900],
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      scaffoldBackgroundColor: AppPalette.backgroundColor,
      appBarTheme: const AppBarTheme().copyWith(
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
