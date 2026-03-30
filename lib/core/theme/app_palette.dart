import 'package:flutter/material.dart';

/// MeTrotro brand colors — matches web server (base.html CSS variables).
///
/// Primary: Teal Green (#16a085) — buttons, active states, key actions
/// Secondary: Navy (#1a1a2e) — text, headers, navigation
/// The teal-on-white palette works for both driver and passenger modes.
class AppPalette {
  // ─── Brand Colors (from web server CSS variables) ─────
  static const Color primary = Color(0xFF16A085);       // --teal-green
  static const Color primaryLight = Color(0xFF1ABC9C);   // --teal-light (hover/active)
  static const Color primaryDark = Color(0xFF0E8C73);    // darker shade for contrast

  static const Color navy = Color(0xFF1A1A2E);           // --navy-dark
  static const Color navyLight = Color(0xFF16213E);      // --navy-light

  // ─── Semantic Colors ──────────────────────────────────
  static const Color success = Color(0xFF16A085);        // same as primary
  static const Color error = Color(0xFFE74C3C);          // --danger
  static const Color warning = Color(0xFFF39C12);        // --warning
  static const Color info = Color(0xFF3498DB);

  // ─── Neutral Colors ───────────────────────────────────
  static const Color backgroundColor = Color(0xFFF5F6FA); // --bg-light
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);     // navy
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF0F0F0);

  // ─── Legacy (backward compatible) ─────────────────────
  static const Color successColor = primaryLight;
  static const Color errorColor = error;
  static const Color activeColor = primaryLight;
  static const Color activeColorBackground = primary;
  static const Color inActiveColor = textSecondary;
  static const Color inActiveColorBackground = Color(0xFFB8B7B7);
  static const Color transparent = Colors.transparent;

  // ─── Helper: MaterialColor swatch from primary ────────
  static const MaterialColor primarySwatch = MaterialColor(0xFF16A085, {
    50: Color(0xFFE8F6F3),
    100: Color(0xFFC5E9E1),
    200: Color(0xFF9FDACD),
    300: Color(0xFF79CBB9),
    400: Color(0xFF5CBFA9),
    500: Color(0xFF16A085),
    600: Color(0xFF13917A),
    700: Color(0xFF0F7F6B),
    800: Color(0xFF0C6E5D),
    900: Color(0xFF074F42),
  });
}
