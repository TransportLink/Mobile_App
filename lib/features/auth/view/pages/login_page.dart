import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/core/providers/user_role_provider.dart';
import 'package:mobileapp/core/theme/app_palette.dart';
import 'package:mobileapp/core/utils/app_utils.dart';
import 'package:mobileapp/core/widgets/app_button.dart';
import 'package:mobileapp/core/widgets/custom_field.dart';
import 'package:mobileapp/core/widgets/loader.dart';
import 'package:mobileapp/features/auth/view/widgets/inactive_button.dart';
import 'package:mobileapp/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:mobileapp/main_screen.dart';
import 'package:mobileapp/passenger/view/passenger_home_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false; // Password visibility toggle

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading =
        ref.watch(authViewmodelProvider.select((val) => val?.isLoading)) ==
            true;

    ref.listen(
      authViewmodelProvider,
      (_, next) => next?.when(
          data: (data) {
            showSnackBar(context, "Welcome back ${data.full_name}!");
            // Push fresh root and clear entire navigation stack
            // This ensures MyApp rebuilds with the correct role
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const _RoleRouter()),
              (route) => false,
            );
          },
          error: (error, stackTrace) {
            final errorMessage = error.toString().replaceAll('Exception: ', '');
            showSnackBar(context, errorMessage);
          },
          loading: () {}),
    );

    return Scaffold(
      backgroundColor: AppPalette.backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: Text("Sign In", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22, color: AppPalette.textPrimary)),
        backgroundColor: AppPalette.surface,
        elevation: 0,
      ),
      body: isLoading
          ? Loader()
          : SafeArea(
              child: SingleChildScrollView(
                child: Container(
                  margin: EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(
                          height: 24,
                        ),
                        // Enhanced image container with rounded corners, border and shadow
                        Container(
                          width: double.infinity,
                          height: 280, // Extended vertically
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppPalette.primary.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.primary.withOpacity(0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              "assets/images/welcome.png",
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Welcome text
                        Text(
                          'Welcome Back!',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 24, color: AppPalette.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue',
                          style: TextStyle(fontSize: 16, color: AppPalette.textSecondary),
                        ),
                        const SizedBox(height: 32),
                        CustomField(
                            label: "Email address",
                            textEditingController: emailController,
                            icon: Icon(Icons.email_outlined, color: AppPalette.primary),
                            hintText: "e.g, abc@email.com"),
                        CustomField(
                            label: "Password",
                            textEditingController: passwordController,
                            icon: Icon(Icons.lock_outline, color: AppPalette.primary),
                            isObscureText: !_isPasswordVisible,
                            hintText: "e.g, ••••••••",
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppPalette.textHint,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: Container(
          height: 80,
          color: AppPalette.surface,
          child: Padding(
            padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
            child: isLoading
                ? InactiveButton("Login")
                : AppButton(
                    text: "Login",
                    onTap: () async {
                      if (!formKey.currentState!.validate()) {
                        showSnackBar(context, "Invalid data in some fields!");
                      } else {
                        ref.read(authViewmodelProvider.notifier).loginUser(
                            email: emailController.text,
                            password: passwordController.text);
                      }
                    },
                  ),
          )),
    );
  }
}

/// Routes to the correct home screen based on user role after login.
class _RoleRouter extends ConsumerWidget {
  const _RoleRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);

    if (role == UserRole.passenger) {
      return const PassengerHomePage();
    }
    return const MainScreen(); // driver + unknown
  }
}
