import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobileapp/core/theme/app_palette.dart';
import 'package:mobileapp/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:mobileapp/features/home/view/pages/auth_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(authViewmodelProvider.notifier).initSharedPreferences();

  runApp(
    UncontrolledProviderScope(container: container, child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: CustomTheme.lightThemeMode,
      home: const AuthPage(),
    );
  }
}

class CustomTheme {
  static final lightThemeMode = ThemeData.light().copyWith(
      scaffoldBackgroundColor: AppPalette.backgroundColor,
      appBarTheme: AppBarThemeData().copyWith(
        backgroundColor: AppPalette.backgroundColor,
        titleTextStyle: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w600,
            color: AppPalette.activeColorBackground,
            fontSize: 24),
      ),
      textTheme: ThemeData.light().textTheme.copyWith(
          bodyLarge: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w400,
              color: AppPalette.activeColorBackground),
          bodyMedium: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w400,
              color: AppPalette.activeColorBackground),
          bodySmall: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w400, color: Colors.black),
          labelMedium: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w400,
              color: AppPalette.activeColorBackground),
          titleLarge: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w400,
              color: AppPalette.activeColorBackground),
          titleMedium: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w400,
              color: AppPalette.activeColorBackground)));
}
