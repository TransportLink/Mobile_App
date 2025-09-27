import 'package:flutter/material.dart';
import 'package:mobileapp/core/widgets/app_button.dart';

class InactiveButton extends StatelessWidget {
  const InactiveButton(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: text,
      onTap: () {},
      active: false,
    );
  }
}
