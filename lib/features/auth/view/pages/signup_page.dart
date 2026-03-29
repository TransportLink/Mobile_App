import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/core/providers/user_role_provider.dart';
import 'package:mobileapp/core/utils/app_utils.dart';
import 'package:mobileapp/core/widgets/app_button.dart';
import 'package:mobileapp/core/widgets/custom_field.dart';
import 'package:mobileapp/core/widgets/loader.dart';
import 'package:mobileapp/features/auth/view/pages/login_page.dart';
import 'package:mobileapp/features/auth/view/widgets/inactive_button.dart';
import 'package:mobileapp/features/auth/viewmodel/auth_viewmodel.dart';

class SignupPage extends ConsumerStatefulWidget {
  final UserRole role;

  const SignupPage({super.key, required this.role});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController licenseNumberController = TextEditingController();
  final TextEditingController licenseExpiryController = TextEditingController();
  final TextEditingController nationalIdController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool get _isDriver => widget.role == UserRole.driver;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneNumberController.dispose();
    dobController.dispose();
    licenseExpiryController.dispose();
    licenseNumberController.dispose();
    nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        firstDate:
            controller == dobController ? DateTime(1900) : DateTime.now(),
        initialDate: DateTime.now(),
        lastDate: controller == dobController
            ? DateTime.now()
            : DateTime.now().add(const Duration(days: 100000)));

    if (picked != null) {
      final formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        controller.text = formatted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading =
        ref.watch(authViewmodelProvider.select((val) => val?.isLoading)) ==
            true;

    ref.listen(authViewmodelProvider, (_, next) {
      next?.when(
          data: (data) {
            // Persist the role before navigating to login
            ref.read(userRoleProvider.notifier).setRole(widget.role);
            showSnackBar(
              context,
              "Account created successfully! Please login",
              isError: false,
            );
            Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LoginPage()));
          },
          error: (error, stackTrace) {
            final errorMessage = error.toString().replaceAll('Exception: ', '');
            showSnackBar(
              context,
              errorMessage,
              isError: true,
              duration: Duration(seconds: 5),
            );
          },
          loading: () {});
    });

    final title = _isDriver ? 'Create Driver Account' : 'Create Account';

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(centerTitle: true, title: Text(title)),
        body: isLoading
            ? Loader()
            : Container(
                margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/images/welcome.png",
                          fit: BoxFit.cover,
                        ),
                        // Role indicator
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _isDriver ? Colors.green.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isDriver ? Colors.green.shade200 : Colors.blue.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isDriver ? Icons.directions_car : Icons.hail_rounded,
                                color: _isDriver ? Colors.green.shade700 : Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isDriver ? 'Signing up as a Driver' : 'Signing up as a Passenger',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _isDriver ? Colors.green.shade700 : Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Common fields (both roles)
                        CustomField(
                            label: "Full name",
                            textEditingController: fullNameController,
                            icon: Icon(Icons.person),
                            hintText: "e.g, John Doe"),
                        CustomField(
                            label: "Email address",
                            textEditingController: emailController,
                            icon: Icon(Icons.email),
                            hintText: "e.g, abc@email.com"),
                        CustomField(
                            label: "Password",
                            textEditingController: passwordController,
                            icon: Icon(Icons.password),
                            isObscureText: true,
                            hintText: "e.g, John Doe"),
                        CustomField(
                            label: "Phone Number",
                            textEditingController: phoneNumberController,
                            icon: Icon(Icons.phone),
                            hintText: "e.g, 0123456789"),
                        // Driver-only fields
                        if (_isDriver) ...[
                          CustomField(
                              label: "Date of Birth",
                              textEditingController: dobController,
                              icon: Icon(Icons.calendar_today_rounded),
                              onTap: () async {
                                await _selectDate(context, dobController);
                              },
                              hintText: "YYYY-MM-DD"),
                          CustomField(
                              label: "License Number",
                              textEditingController: licenseNumberController,
                              icon: Icon(Icons.numbers),
                              hintText: "0000-0000-0000"),
                          CustomField(
                              label: "License Expiry",
                              textEditingController: licenseExpiryController,
                              icon: Icon(Icons.calendar_today_rounded),
                              onTap: () async {
                                await _selectDate(
                                    context, licenseExpiryController);
                              },
                              hintText: "YYYY-MM-DD"),
                          CustomField(
                              label: "National ID",
                              textEditingController: nationalIdController,
                              icon: Icon(Icons.numbers),
                              hintText: "0000-0000-0000"),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: Container(
          height: 72,
          color: Colors.white,
          child: isLoading
              ? InactiveButton("Create an account")
              : AppButton(
                  text: "Create an account",
                  onTap: () async {
                    if (!formKey.currentState!.validate()) {
                      showSnackBar(context, "Invalid data in some fields!");
                    } else {
                      await ref
                          .read(authViewmodelProvider.notifier)
                          .registerUser(
                              full_name: fullNameController.text,
                              email: emailController.text,
                              password: passwordController.text,
                              phone_number: phoneNumberController.text,
                              date_of_birth: _isDriver
                                  ? dobController.text
                                  : "",
                              license_number: _isDriver
                                  ? "LIC${licenseNumberController.text}"
                                  : "",
                              license_expiry: _isDriver
                                  ? licenseExpiryController.text
                                  : "",
                              national_id: _isDriver
                                  ? "NID${nationalIdController.text}"
                                  : "");
                    }
                  }),
        ),
      ),
    );
  }
}
