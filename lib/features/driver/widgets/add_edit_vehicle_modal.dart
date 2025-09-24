import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobileapp/core/model/vehicle_model.dart';
import 'package:mobileapp/features/driver/utils/vehicle_utils.dart';
import 'package:mobileapp/features/driver/widgets/vehicle_widgets.dart';
import 'package:mobileapp/features/driver/viewmodel/vehicle_view_model.dart';

class AddEditVehicleModal extends ConsumerStatefulWidget {
  final VehicleModel? vehicle; // null for add, non-null for edit
  final VoidCallback onClose;

  const AddEditVehicleModal({
    super.key,
    this.vehicle,
    required this.onClose,
  });

  @override
  ConsumerState<AddEditVehicleModal> createState() => _AddEditVehicleModalState();
}

class _AddEditVehicleModalState extends ConsumerState<AddEditVehicleModal> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // Form controllers
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _plateNumberController;
  late TextEditingController _colorController;
  late TextEditingController _vehicleTypeController;
  late TextEditingController _seatingCapacityController;
  late TextEditingController _insuranceNumberController;
  late TextEditingController _insuranceExpiryDateController;

  File? _selectedPhoto;
  Map<String, String?> _formErrors = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final vehicle = widget.vehicle;
    
    _brandController = TextEditingController(text: vehicle?.brand ?? '');
    _modelController = TextEditingController(text: vehicle?.model ?? '');
    _yearController = TextEditingController(text: vehicle?.year ?? '');
    _plateNumberController = TextEditingController(text: vehicle?.plateNumber ?? '');
    _colorController = TextEditingController(text: vehicle?.color ?? '');
    _vehicleTypeController = TextEditingController(text: vehicle?.vehicleType ?? '');
    _seatingCapacityController = TextEditingController(
      text: vehicle?.seatingCapacity?.toString() ?? ''
    );
    _insuranceNumberController = TextEditingController(text: vehicle?.insuranceNumber ?? '');
    _insuranceExpiryDateController = TextEditingController(text: vehicle?.insuranceExpiryDate ?? '');
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateNumberController.dispose();
    _colorController.dispose();
    _vehicleTypeController.dispose();
    _seatingCapacityController.dispose();
    _insuranceNumberController.dispose();
    _insuranceExpiryDateController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        _selectedPhoto = File(photo.path);
      });
    }
  }

  Future<void> _selectInsuranceExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _insuranceExpiryDateController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedPhoto = null;
    });
  }

  Future<void> _saveVehicle() async {
    // Validate form
    final errors = VehicleUtils.validateVehicleData(
      brand: _brandController.text,
      model: _modelController.text,
      year: _yearController.text,
      plateNumber: _plateNumberController.text,
      color: _colorController.text,
      seatingCapacity: _seatingCapacityController.text,
      insuranceNumber: _insuranceNumberController.text,
      insuranceExpiryDate: _insuranceExpiryDateController.text,
    );

    if (errors.isNotEmpty) {
      setState(() {
        _formErrors = errors;
      });
      return;
    }

    setState(() {
      _formErrors = {};
    });

    // Prepare data to match backend API
    final data = <String, dynamic>{
      'brand': _brandController.text.trim(),
      'model': _modelController.text.trim(),
      'year': _yearController.text.trim(),
      'plate_number': _plateNumberController.text.trim(),
      'color': _colorController.text.trim(),
    };

    // Add optional fields only if they have values
    if (_vehicleTypeController.text.trim().isNotEmpty) {
      data['vehicle_type'] = _vehicleTypeController.text.trim();
    }

    if (_seatingCapacityController.text.trim().isNotEmpty) {
      data['seating_capacity'] = int.tryParse(_seatingCapacityController.text.trim());
    }

    if (_insuranceNumberController.text.trim().isNotEmpty) {
      data['insurance_number'] = _insuranceNumberController.text.trim();
    }

    if (_insuranceExpiryDateController.text.trim().isNotEmpty) {
      data['insurance_expiry_date'] = _insuranceExpiryDateController.text.trim();
    }

    try {
      final vehicleViewModel = ref.read(vehicleViewModelProvider.notifier);
      
      if (widget.vehicle == null) {
        await vehicleViewModel.addVehicle(
          data: data,
          photoPath: _selectedPhoto?.path,
        );
      } else {
        await vehicleViewModel.updateVehicle(
          vehicleId: widget.vehicle!.vehicleId!,
          data: data,
          photoPath: _selectedPhoto?.path,
        );
      }

      if (mounted) {
        ref.invalidate(getAllVehiclesProvider);
        
        _showSuccessMessage(
          widget.vehicle == null 
              ? 'Vehicle added successfully'
              : 'Vehicle updated successfully'
        );
        widget.onClose();
      }
    } catch (e) {
      _showErrorMessage('Failed to save vehicle: $e');
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleState = ref.watch(vehicleViewModelProvider);
    final isEditing = widget.vehicle != null;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModalHeader(isEditing),
                  const SizedBox(height: 24),
                  _buildPhotoSection(),
                  const SizedBox(height: 24),
                  _buildBasicInfoSection(),
                  const SizedBox(height: 24),
                  _buildOptionalInfoSection(),
                  const SizedBox(height: 32),
                  _buildActionButtons(vehicleState),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalHeader(bool isEditing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isEditing ? 'Edit Vehicle' : 'Add Vehicle',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        IconButton(
          onPressed: widget.onClose,
          icon: const Icon(Icons.close, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Photo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        VehicleWidgets.buildPhotoUploadArea(
          selectedPhoto: _selectedPhoto,
          currentPhotoUrl: widget.vehicle?.photoUrl,
          onTap: _pickPhoto,
          onRemove: _removePhoto,
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Basic Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          controller: _brandController,
          label: 'Brand *',
          items: VehicleUtils.getVehicleBrands(),
          errorText: _formErrors['brand'],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _modelController,
          label: 'Model *',
          errorText: _formErrors['model'],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                controller: _yearController,
                label: 'Year *',
                items: VehicleUtils.getVehicleYears(),
                errorText: _formErrors['year'],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdownField(
                controller: _colorController,
                label: 'Color *',
                items: VehicleUtils.getVehicleColors(),
                errorText: _formErrors['color'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _plateNumberController,
          label: 'Plate Number *',
          errorText: _formErrors['plateNumber'],
        ),
      ],
    );
  }

  Widget _buildOptionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                controller: _vehicleTypeController,
                label: 'Vehicle Type',
                items: VehicleUtils.getVehicleTypes(),
                isRequired: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _seatingCapacityController,
                label: 'Seating Capacity',
                keyboardType: TextInputType.number,
                errorText: _formErrors['seatingCapacity'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _insuranceNumberController,
          label: 'Insurance Number',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _insuranceExpiryDateController,
          label: 'Insurance Expiry Date',
          readOnly: true,
          onTap: _selectInsuranceExpiryDate,
          suffixIcon: const Icon(Icons.calendar_today),
          errorText: _formErrors['insuranceExpiryDate'],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(color: Colors.black, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        errorText: errorText,
        labelStyle: const TextStyle(color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required List<String> items,
    String? errorText,
    bool isRequired = true,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: controller.text.isEmpty ? null : controller.text,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        labelStyle: const TextStyle(color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: (value) {
        controller.text = value ?? '';
      },
    );
  }

  Widget _buildActionButtons(AsyncValue<dynamic>? vehicleState) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onClose,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.black12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: vehicleState?.isLoading == true ? null : _saveVehicle,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: vehicleState?.isLoading == true
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.vehicle == null ? 'Add Vehicle' : 'Update Vehicle',
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }
}