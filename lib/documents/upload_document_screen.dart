import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

class UploadDocumentScreen extends StatefulWidget {
  final String accessToken;
  const UploadDocumentScreen({super.key, required this.accessToken});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  String? _documentType;
  XFile? _documentFile;
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _documentNumberController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _documentFile = pickedFile);
    }
  }

  Future<void> _uploadDocument() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final result = await _authService.uploadDocument(
          accessToken: widget.accessToken,
          documentType: _documentType!,
          documentNumber: _documentNumberController.text,
          expiryDate: _expiryDateController.text,
          documentPath: _documentFile?.path,
        );

        setState(() => _isLoading = false);
        if (result['success']) {
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to upload document')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Document'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickDocument,
                child: Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: _documentFile == null
                      ? const Center(child: Text('Tap to select document'))
                      : Image.file(File(_documentFile!.path), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _documentType,
                decoration: const InputDecoration(
                  labelText: 'Document Type',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: ['license', 'insurance', 'vehicle_registration', 'ID_card']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type.replaceAll('_', ' ').toUpperCase())))
                    .toList(),
                onChanged: (value) => setState(() => _documentType = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _documentNumberController,
                decoration: const InputDecoration(
                  labelText: 'Document Number',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expiryDateController,
                decoration: const InputDecoration(
                  labelText: 'Expiry Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) =>
                    value!.isEmpty || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)
                        ? 'Enter a valid date (YYYY-MM-DD)'
                        : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _uploadDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Upload Document', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}