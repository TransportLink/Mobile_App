import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobileapp/core/widgets/app_button.dart';
import 'package:mobileapp/features/auth/view/pages/login_page.dart';
import 'package:mobileapp/features/auth/view/pages/signup_page.dart';

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
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(boxShadow: [
              BoxShadow(
                  color: Colors.green.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(4, 4))
            ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "Be your own boss.\nDrive with pride.",
                  style: GoogleFonts.bricolageGrotesque(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                    "Make money by helping passengers to get to their destination.",
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 18,
                      color: Colors.white60,
                    )),
                const Spacer(),
                AppButton(
                  gradientColors: [
                    const Color.fromARGB(255, 72, 209, 76),
                    const Color.fromARGB(255, 113, 204, 8)
                  ],
                  text: "Create an account",
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SignupPage(),
                    ),
                  ),
                ),
                SizedBox(
                  height: 60,
                  child: Center(
                    child: RichText(
                      text: TextSpan(
                        text: "Already have an account? ",
                        style: GoogleFonts.bricolageGrotesque(fontSize: 14),
                        children: [
                          TextSpan(
                              text: "Login  →",
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => LoginPage(),
                                    ),
                                  );
                                },
                              style:
                                  GoogleFonts.bricolageGrotesque(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
