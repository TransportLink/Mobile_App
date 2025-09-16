import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class VehicleDetailScreen extends StatefulWidget {
  final String vehicleId;

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateNumberController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _seatingCapacityController = TextEditingController();
  final _insuranceNumberController = TextEditingController();
  final _insuranceExpiryController = TextEditingController();
  String? _vehicleType;
  String? _photoUrl;
  XFile? _newPhoto;
  bool _isLoading = true;
  bool _isEditing = false;

  final AuthService _authService =
      AuthService(); 

  @override
  void initState() {
    super.initState();
    _fetchVehicle();
  }

  Future<void> _fetchVehicle() async {
    try {
      final result = await _authService.getVehicle(widget.vehicleId);
      if (!result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message'] ?? 'Failed to fetch vehicle')),
        );
        Navigator.pop(context);
        return;
      }
      final vehicle = result['data'];
      setState(() {
        _plateNumberController.text = vehicle['plate_number'] ?? '';
        _vehicleType = vehicle['vehicle_type'];
        _brandController.text = vehicle['brand'] ?? '';
        _modelController.text = vehicle['model'] ?? '';
        _yearController.text = vehicle['year']?.toString() ?? '';
        _colorController.text = vehicle['color'] ?? '';
        _seatingCapacityController.text =
            vehicle['seating_capacity']?.toString() ?? '';
        _insuranceNumberController.text = vehicle['insurance_number'] ?? '';
        _insuranceExpiryController.text =
            vehicle['insurance_expiry_date'] ?? '';
        _photoUrl = vehicle['photo_url'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _newPhoto = pickedFile);
    }
  }

  Future<void> _updateVehicle() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final prefs = await SharedPreferences.getInstance();
        final accessToken = prefs.getString('access_token') ?? '';
        final data = {
          'plate_number': _plateNumberController.text,
          'vehicle_type': _vehicleType,
          'brand': _brandController.text,
          'model': _modelController.text,
          'year': int.parse(_yearController.text),
          'color': _colorController.text,
          'seating_capacity': int.parse(_seatingCapacityController.text),
          'insurance_number': _insuranceNumberController.text,
          'insurance_expiry_date': _insuranceExpiryController.text,
        };

        final result = await _authService.updateVehicle(widget.vehicleId, data,
            photoPath: _newPhoto?.path, accessToken: accessToken);

        setState(() => _isLoading = false);
        if (result['success']) {
          setState(() {
            _photoUrl = result['data']['photo_url'];
            _newPhoto = null;
            _isEditing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle updated')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['message'] ?? 'Failed to update vehicle')),
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

  Future<void> _deleteVehicle() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';
      final result = await _authService.deleteVehicle(widget.vehicleId,
          accessToken: accessToken);
      setState(() => _isLoading = false);
      if (result['success']) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message'] ?? 'Failed to delete vehicle')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _plateNumberController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _seatingCapacityController.dispose();
    _insuranceNumberController.dispose();
    _insuranceExpiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Details'),
        backgroundColor: Colors.indigo,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Vehicle'),
                  content: const Text(
                      'Are you sure you want to delete this vehicle?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteVehicle();
                      },
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    GestureDetector(
                      onTap: _isEditing ? _pickImage : null,
                      child: Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: _newPhoto != null
                            ? Image.file(File(_newPhoto!.path),
                                fit: BoxFit.cover)
                            : _photoUrl != null
                                ? Image.network(_photoUrl!, fit: BoxFit.cover)
                                : const Center(
                                    child: Text('No photo available')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _plateNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Plate Number',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      enabled: _isEditing,
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _vehicleType,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Type',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: ['car', 'van', 'bus', 'bike', 'other']
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: _isEditing
                          ? (value) => setState(() => _vehicleType = value)
                          : null,
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          value!.isEmpty || int.tryParse(value) == null
                              ? 'Enter a valid year'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _colorController,
                      decoration: const InputDecoration(
                        labelText: 'Color',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _seatingCapacityController,
                      decoration: const InputDecoration(
                        labelText: 'Seating Capacity',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          value!.isEmpty || int.tryParse(value) == null
                              ? 'Enter a valid number'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _insuranceNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Insurance Number',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _insuranceExpiryController,
                      decoration: const InputDecoration(
                        labelText: 'Insurance Expiry Date (YYYY-MM-DD)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      enabled: _isEditing,
                      validator: (value) => value!.isEmpty ||
                              !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)
                          ? 'Enter a valid date (YYYY-MM-DD)'
                          : null,
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateVehicle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Update Vehicle',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
