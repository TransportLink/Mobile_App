import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'services/auth_service.dart';
import 'logout.dart';

class DriverProfileScreen extends StatefulWidget {
  final String accessToken;
  const DriverProfileScreen({super.key, required this.accessToken});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _driverInfo;
  bool _isLoading = true;
  bool _isEditing = false;
  String? _error;

  // Form controllers
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _dobController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _licenseExpiryController = TextEditingController();
  final _nationalIdController = TextEditingController();

  // Image picker state
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
  }

  Future<void> _loadDriverInfo() async {
    final result = await _authService.fetchDriverProfile(widget.accessToken);
    if (result["success"]) {
      setState(() {
        _driverInfo = result["data"];
        _fullNameController.text = _driverInfo!["full_name"] ?? "";
        _phoneNumberController.text = _driverInfo!["phone_number"] ?? "";
        _dobController.text = _driverInfo!["date_of_birth"] ?? "";
        _licenseNumberController.text = _driverInfo!["license_number"] ?? "";
        _licenseExpiryController.text =
            _driverInfo!["license_expiry_date"] ?? "";
        _nationalIdController.text = _driverInfo!["national_id"] ?? "";
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result["message"];
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_isEditing) return;

    final formKey = GlobalKey<FormState>();
    if (formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      final data = {
        "full_name": _fullNameController.text,
        "phone_number": _phoneNumberController.text,
        "date_of_birth": _dobController.text,
        "license_number": _licenseNumberController.text,
        "license_expiry_date": _licenseExpiryController.text,
        "national_id": _nationalIdController.text,
      };

      try {
        final result = await _authService.updateDriverProfile(
          accessToken: widget.accessToken,
          data: data,
          photoPath: _profileImage?.path,
        );

        setState(() => _isLoading = false);

        if (result["success"]) {
          setState(() {
            _driverInfo = result["data"];
            _profileImage = null; // Clear after successful upload
            _isEditing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result["message"] ?? "Failed to update profile")),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildInfoTile(String label, String value, IconData icon,
      {bool editable = false, TextEditingController? controller}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: _isEditing && editable
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon, color: Colors.blueAccent),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (label == "Full Name" || label == "Phone Number") {
                    return value!.isEmpty ? 'Please enter $label' : null;
                  }
                  return null;
                },
              ),
            )
          : ListTile(
              leading: Icon(icon, color: Colors.blueAccent),
              title: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black54)),
              subtitle: Text(value, style: const TextStyle(fontSize: 16)),
            ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _dobController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Profile'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: "Edit Profile",
              onPressed: () {
                setState(() => _isEditing = true);
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Logout",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogoutScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                )
              : _driverInfo == null
                  ? const Center(child: Text('No driver info found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: GlobalKey<FormState>(),
                        child: Column(
                          children: [
                            // Profile Header with image picker + plus icon
                            Stack(
                              children: [
                                GestureDetector(
                                  onTap: _isEditing ? _pickImage : null,
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.blueAccent,
                                    backgroundImage: _profileImage != null
                                        ? FileImage(_profileImage!)
                                        : (_driverInfo!["profile_photo_url"] !=
                                                null
                                            ? NetworkImage(_driverInfo![
                                                "profile_photo_url"])
                                            : null) as ImageProvider?,
                                    child: (_profileImage == null &&
                                            (_driverInfo![
                                                        "profile_photo_url"] ==
                                                    null ||
                                                _driverInfo![
                                                        "profile_photo_url"]
                                                    .isEmpty))
                                        ? Text(
                                            (_driverInfo!["full_name"] !=
                                                        null &&
                                                    _driverInfo!["full_name"]
                                                        .isNotEmpty)
                                                ? _driverInfo!["full_name"][0]
                                                    .toUpperCase()
                                                : "?",
                                            style: const TextStyle(
                                                fontSize: 40,
                                                color: Colors.white),
                                          )
                                        : null,
                                  ),
                                ),
                                if (_isEditing)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _pickImage,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: const Icon(
                                          Icons.add_a_photo,
                                          size: 22,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _driverInfo!["full_name"] ?? "Not set",
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _driverInfo!["email"] ?? "Not set",
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            // Info List
                            _buildInfoTile(
                              "Full Name",
                              _driverInfo!["full_name"] ?? "Not set",
                              Icons.person,
                              editable: true,
                              controller: _fullNameController,
                            ),
                            _buildInfoTile(
                              "Phone",
                              _driverInfo!["phone_number"] ?? "Not set",
                              Icons.phone,
                              editable: true,
                              controller: _phoneNumberController,
                            ),
                            _buildInfoTile(
                              "Date of Birth",
                              _driverInfo!["date_of_birth"] ?? "Not set",
                              Icons.cake,
                              editable: true,
                              controller: _dobController,
                            ),
                            _buildInfoTile(
                              "License Number",
                              _driverInfo!["license_number"] ?? "Not set",
                              Icons.card_membership,
                              editable: true,
                              controller: _licenseNumberController,
                            ),
                            _buildInfoTile(
                              "License Expiry",
                              _driverInfo!["license_expiry_date"] ?? "Not set",
                              Icons.date_range,
                              editable: true,
                              controller: _licenseExpiryController,
                            ),
                            _buildInfoTile(
                              "National ID",
                              _driverInfo!["national_id"] ?? "Not set",
                              Icons.credit_card,
                              editable: true,
                              controller: _nationalIdController,
                            ),
                            _buildInfoTile(
                              "Status",
                              _driverInfo!["status"] ?? "Not set",
                              Icons.verified_user,
                            ),
                            _buildInfoTile(
                              "Created At",
                              _driverInfo!["created_at"] ?? "Not set",
                              Icons.calendar_today,
                            ),
                            _buildInfoTile(
                              "Updated At",
                              _driverInfo!["updated_at"] ?? "Not set",
                              Icons.update,
                            ),
                            if (_isEditing) ...[
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _updateProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  textStyle: const TextStyle(fontSize: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text('Save Profile'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
    );
  }
}
