import 'dart:io';

import 'package:flutter/material.dart';

class ProfileState {
  final bool isEditing;
  final File? selectedImage;

  // Form controllers
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController dobController;
  final TextEditingController licenseNumberController;
  final TextEditingController licenseExpiryController;
  final TextEditingController nationalIdController;

  ProfileState({
    this.isEditing = false,
    this.selectedImage,
    TextEditingController? fullNameController,
    TextEditingController? emailController,
    TextEditingController? phoneController,
    TextEditingController? dobController,
    TextEditingController? licenseNumberController,
    TextEditingController? licenseExpiryController,
    TextEditingController? nationalIdController,
  })  : fullNameController = fullNameController ?? TextEditingController(),
        emailController = emailController ?? TextEditingController(),
        phoneController = phoneController ?? TextEditingController(),
        dobController = dobController ?? TextEditingController(),
        licenseNumberController =
            licenseNumberController ?? TextEditingController(),
        licenseExpiryController =
            licenseExpiryController ?? TextEditingController(),
        nationalIdController = nationalIdController ?? TextEditingController();

  ProfileState copyWith({
    bool? isEditing,
    File? selectedImage,
  }) {
    return ProfileState(
      isEditing: isEditing ?? this.isEditing,
      selectedImage: selectedImage ?? this.selectedImage,
      fullNameController: fullNameController,
      emailController: emailController,
      phoneController: phoneController,
      dobController: dobController,
      licenseNumberController: licenseNumberController,
      licenseExpiryController: licenseExpiryController,
      nationalIdController: nationalIdController,
    );
  }
}
