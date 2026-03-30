import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobileapp/core/theme/app_palette.dart';

class CustomField extends StatelessWidget {
  const CustomField(
      {super.key,
      required this.label,
      required this.textEditingController,
      required this.hintText,
      required this.icon,
      this.validation,
      this.onTap,
      this.isObscureText = false,
      this.suffixIcon});

  final String label;
  final String hintText;
  final TextEditingController textEditingController;
  final FormFieldValidator<String?>? validation;
  final VoidCallback? onTap;
  final Icon icon;
  final bool isObscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: Column(
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
              suffixIcon: suffixIcon,
              hintText: hintText,
              hintStyle: GoogleFonts.bricolageGrotesque(
                  fontSize: 18, color: AppPalette.textHint),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppPalette.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppPalette.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: AppPalette.surface,
            ),
          )
        ],
      ),
    );
  }
}
