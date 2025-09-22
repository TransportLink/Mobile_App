import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomField extends StatelessWidget {
  const CustomField(
      {Key? key,
      required this.label,
      required this.textEditingController,
      required this.hintText,
      required this.icon,
      this.validation,
      this.onTap,
      this.isObscureText = false})
      : super(key: key);

  final String label;
  final String hintText;
  final TextEditingController textEditingController;
  final FormFieldValidator<String?>? validation;
  final VoidCallback? onTap;
  final Icon icon;
  final bool isObscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 10,
        ),
        Text(label, style: GoogleFonts.bricolageGrotesque(fontSize: 16)),
        const SizedBox(
          height: 6,
        ),
        TextFormField(
          controller: textEditingController,
          validator: validation ??
              (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Value can not be empty";
                }

                return null;
              },
          obscureText: isObscureText,
          onTap: onTap,
          decoration: InputDecoration(
            prefixIcon: icon,
            hintText: hintText,
            hintStyle: GoogleFonts.bricolageGrotesque(
                fontSize: 18, color: Color.fromARGB(255, 173, 173, 173)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color.fromARGB(255, 216, 216, 216), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.black,
              ),
            ),
          ),
        )
      ],
    );
  }
}
