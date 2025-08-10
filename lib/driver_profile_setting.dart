import 'package:flutter/material.dart';

import 'logout.dart';

class DriverProfileSetting extends StatefulWidget {
  const DriverProfileSetting({super.key});

  @override
  State<DriverProfileSetting> createState() => _DriverProfileSettingState();
}

class _DriverProfileSettingState extends State<DriverProfileSetting> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _seatsController = TextEditingController();
  final _vehicleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Settings'),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.indigo.shade100,
                      child: const Icon(Icons.settings,
                          size: 40, color: Colors.indigo),
                    ),
                    const SizedBox(height: 18),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      validatorText: 'Please enter your name',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validatorText: 'Enter your phone number',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _seatsController,
                      label: 'Number of Seats',
                      icon: Icons.event_seat,
                      keyboardType: TextInputType.number,
                      validatorText: 'Enter number of seats',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _vehicleController,
                      label: 'Vehicle Info',
                      icon: Icons.directions_car,
                      validatorText: 'Enter vehicle information',
                    ),
                    const SizedBox(height: 28),
                    _buildPrimaryButton(
                      text: 'Save and Continue',
                      icon: Icons.save,
                      color: Colors.indigo,
                      onPressed: _saveProfile,
                    ),
                    const SizedBox(height: 16),
                    _buildPrimaryButton(
                      text: 'Logout',
                      icon: Icons.logout,
                      color: Colors.red,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LogoutScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _seatsController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  Widget _buildPrimaryButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String validatorText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      validator: (value) => value!.isEmpty ? validatorText : null,
    );
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushNamed(
        context,
        '/profile',
        arguments: {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'seats': _seatsController.text,
          'vehicle': _vehicleController.text,
        },
      );
    }
  }
}
