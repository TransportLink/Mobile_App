import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppButton extends StatelessWidget {
  const AppButton(
      {super.key,
      required this.text,
      required this.onTap,
      this.gradientColors});

  final String text;
  final VoidCallback onTap;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Ink(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
              colors: gradientColors ??
                  [Colors.black, Colors.black.withOpacity(0.8)]),
        ),
        child: Align(
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.bricolageGrotesque(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
