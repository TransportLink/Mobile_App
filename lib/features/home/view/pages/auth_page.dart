import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobileapp/core/widgets/app_button.dart';
import 'package:mobileapp/features/auth/view/pages/login_page.dart';
import 'package:mobileapp/features/auth/view/pages/role_selection_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/images/background/driver_bg.jpg"),
                fit: BoxFit.cover),
          ),
        ),
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.green.withOpacity(0.2),
                Colors.green
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            alignment: Alignment.bottomLeft,
            margin: EdgeInsets.all(8),
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            decoration: BoxDecoration(boxShadow: [
              BoxShadow(
                  color: Colors.green.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(4, 4))
            ]),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Smart Trotro",
                    style: GoogleFonts.bricolageGrotesque(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      "Real-time trotro demand for drivers. Live tracking for passengers.",
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        color: Colors.white60,
                      )),
                  const SizedBox(height: 20),
                  AppButton(
                    gradientColors: [
                      const Color.fromARGB(255, 72, 209, 76),
                      const Color.fromARGB(255, 113, 204, 8)
                    ],
                    text: "Login",
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => LoginPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    gradientColors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                    text: "Create an account",
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RoleSelectionPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
