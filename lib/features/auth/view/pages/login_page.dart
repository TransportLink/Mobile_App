import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/core/utils/app_utils.dart';
import 'package:mobileapp/core/widgets/app_button.dart';
import 'package:mobileapp/core/widgets/custom_field.dart';
import 'package:mobileapp/core/widgets/loader.dart';
import 'package:mobileapp/features/auth/view/widgets/inactive_button.dart';
import 'package:mobileapp/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:mobileapp/main_screen.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

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
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const MainScreen()));
          },
          error: (error, stackTrace) {
            showSnackBar(context, error.toString());
          },
          loading: () {}),
    );

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text("Sign In")),
      body: isLoading
          ? Loader()
          : SafeArea(
              child: SingleChildScrollView(
                child: Container(
                  margin: EdgeInsets.fromLTRB(10, 0, 10, 0),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      spacing: 12,
                      children: [
                        const SizedBox(
                          height: 12,
                        ),
                        Image.asset(
                          "assets/images/welcome.png",
                          fit: BoxFit.cover,
                        ),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: Container(
          height: 72,
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.only(bottom: 20),
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
