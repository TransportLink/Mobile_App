import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobileapp/core/model/user_model.dart';
import 'package:mobileapp/core/providers/current_user_notifier.dart';
import 'package:mobileapp/core/providers/user_role_provider.dart';
import 'package:mobileapp/features/auth/utils/auth_utils.dart';
import 'package:mobileapp/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:mobileapp/features/driver/view/wallet_page.dart';
import 'package:mobileapp/features/driver/view/vehicle_page.dart';
import 'package:mobileapp/features/driver/view/driver_documents_page.dart';

/// Account hub — shows profile summary + menu items for all account features.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserNotifierProvider);
    final role = ref.watch(userRoleProvider);
    final isDriver = role == UserRole.driver;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Profile card
              _ProfileCard(user: user),
              const SizedBox(height: 24),

              // Account section
              _SectionLabel('Account'),
              const SizedBox(height: 8),
              _MenuItem(
                icon: Icons.person_outline,
                label: 'Edit Profile',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage())),
              ),
              if (isDriver) ...[
                _MenuItem(
                  icon: Icons.directions_car_outlined,
                  label: 'My Vehicles',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const VehiclesPage())),
                ),
                _MenuItem(
                  icon: Icons.folder_outlined,
                  label: 'Documents',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DriverDocumentsPage())),
                ),
              ],
              if (isDriver)
                _MenuItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Wallet',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const WalletPage())),
                ),

              const SizedBox(height: 20),

              // App section
              _SectionLabel('App'),
              const SizedBox(height: 8),
              _MenuItem(
                icon: Icons.info_outline,
                label: 'About Smart Trotro',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Smart Trotro',
                    applicationVersion: '1.0.0',
                    children: [
                      const Text('Real-time trotro demand for drivers.\nLive tracking for passengers.'),
                    ],
                  );
                },
              ),
              _MenuItem(
                icon: Icons.logout,
                label: 'Log Out',
                color: Colors.red,
                onTap: () => logOut(ref, context),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserModel? user;
  const _ProfileCard({this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade200, width: 2),
            ),
            child: user?.profile_photo_url != null && user!.profile_photo_url!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.network(
                      user!.profile_photo_url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.person, size: 40, color: Colors.grey.shade400),
                    ),
                  )
                : Icon(Icons.person, size: 40, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 12),
          Text(
            user?.full_name ?? 'User',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          if (user?.phone_number != null && user!.phone_number.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              user!.phone_number,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? Colors.black87;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: itemColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: itemColor)),
                ),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Edit Profile Page (opens from menu) ──────────────────

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _licenseNumberController;
  late TextEditingController _licenseExpiryController;
  late TextEditingController _nationalIdController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserNotifierProvider);
    _fullNameController = TextEditingController(text: user?.full_name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone_number ?? '');
    _dobController = TextEditingController(text: user?.date_of_birth ?? '');
    _licenseNumberController = TextEditingController(text: user?.license_number ?? '');
    _licenseExpiryController = TextEditingController(text: user?.license_expiry ?? '');
    _nationalIdController = TextEditingController(text: user?.national_id ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      controller.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserNotifierProvider);
    if (user == null) return;

    ref.read(currentUserNotifierProvider.notifier).addCurrentUser(user.copyWith(
          full_name: _fullNameController.text,
          email: _emailController.text,
          phone_number: _phoneController.text,
          date_of_birth: _dobController.text,
          license_number: _licenseNumberController.text,
          license_expiry: _licenseExpiryController.text,
          national_id: _nationalIdController.text,
        ));

    await ref.read(authViewmodelProvider.notifier).updateUserData(_selectedImage?.path);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    final isDriver = role == UserRole.driver;
    final isLoading = ref.watch(authViewmodelProvider)?.isLoading == true;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar with camera button
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade100,
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : null,
                            child: _selectedImage == null
                                ? Icon(Icons.person, size: 50, color: Colors.grey.shade400)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                  color: Colors.black, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _field(_fullNameController, 'Full Name', Icons.person_outline),
                    _field(_emailController, 'Email', Icons.email_outlined,
                        type: TextInputType.emailAddress),
                    _field(_phoneController, 'Phone Number', Icons.phone_outlined,
                        type: TextInputType.phone),
                    if (isDriver) ...[
                      _field(_dobController, 'Date of Birth', Icons.calendar_today_outlined,
                          readOnly: true, onTap: () => _selectDate(_dobController)),
                      _field(_licenseNumberController, 'License Number', Icons.credit_card_outlined),
                      _field(_licenseExpiryController, 'License Expiry', Icons.event_outlined,
                          readOnly: true, onTap: () => _selectDate(_licenseExpiryController)),
                      _field(_nationalIdController, 'National ID', Icons.badge_outlined),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Save Changes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {TextInputType? type, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
        ),
      ),
    );
  }
}
