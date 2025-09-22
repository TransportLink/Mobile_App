import 'package:flutter/material.dart';
import 'package:mobileapp/core/widgets/app_button.dart';
import 'package:mobileapp/core/widgets/custom_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text("Sign In")),
      body: Container(
        margin: EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
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
      bottomNavigationBar: Container(
        height: 72,
        color: Colors.white,
        child: AppButton(
          text: "Login",
          onTap: () {},
        ),
      ),
    );
  }
}
