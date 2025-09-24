import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobileapp/core/model/driver_document.dart';
import 'package:mobileapp/features/driver/utils/driver_utils.dart';
import 'package:mobileapp/features/driver/widgets/document_widgets.dart';
import 'package:mobileapp/features/driver/viewmodel/driver_view_model.dart';

class UploadDocumentModal extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const UploadDocumentModal({
    super.key,
    required this.onClose,
  });

  @override
  ConsumerState<UploadDocumentModal> createState() =>
      _UploadDocumentModalState();
}

class _UploadDocumentModalState extends ConsumerState<UploadDocumentModal> {
  final ImagePicker _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _documentTypeController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  File? _selectedDocument;

  @override
  void dispose() {
    _documentTypeController.dispose();
    _documentNumberController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (file != null) {
      setState(() {
        _selectedDocument = File(file.path);
      });
    }
  }

  Future<void> _selectExpiryDate() async {
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
      _expiryDateController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _uploadDocument() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDocument == null) {
      _showErrorMessage('Please select a document to upload');
      return;
    }

    try {
      await ref.read(driverViewModelProvider.notifier).uploadDocument(
            documentType: _documentTypeController.text,
            documentNumber: _documentNumberController.text,
            expiryDate: _expiryDateController.text,
            documentFile: _selectedDocument?.absolute,
          );

      if (mounted) {
        // Refresh the documents list
        ref.invalidate(getAllDocumentsProvider);

        _showSuccessMessage('Document uploaded successfully');
        widget.onClose();
      }
    } catch (e) {
      _showErrorMessage('Failed to upload document: $e');
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

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverViewModelProvider);

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
                  _buildModalHeader(),
                  const SizedBox(height: 24),
                  _buildDocumentTypeDropdown(),
                  const SizedBox(height: 16),
                  _buildDocumentNumberField(),
                  const SizedBox(height: 16),
                  _buildExpiryDateField(),
                  const SizedBox(height: 24),
                  _buildDocumentUploadArea(),
                  const SizedBox(height: 32),
                  _buildActionButtons(driverState),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Upload Document',
          style: TextStyle(
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

  Widget _buildDocumentTypeDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Document Type *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a document type';
        }
        return null;
      },
      items: DriverUtils.getDocumentTypes().map((type) {
        return DropdownMenuItem(
            value: type, child: Text(type.split("_").join(" ")));
      }).toList(),
      onChanged: (value) {
        _documentTypeController.text = value ?? '';
      },
    );
  }

  Widget _buildDocumentNumberField() {
    return TextFormField(
      controller: _documentNumberController,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter document number';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Document Number *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildExpiryDateField() {
    return TextFormField(
      controller: _expiryDateController,
      readOnly: true,
      onTap: _selectExpiryDate,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select expiry date';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Expiry Date *',
        suffixIcon: const Icon(Icons.calendar_today),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildDocumentUploadArea() {
    return DocumentWidgets.buildDocumentUploadArea(
      selectedDocument: _selectedDocument,
      onTap: _pickDocument,
      onRemove: () {
        setState(() {
          _selectedDocument = null;
        });
      },
    );
  }

  Widget _buildActionButtons(AsyncValue<DriverDocument>? driverState) {
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
            onPressed: driverState?.isLoading == true ? null : _uploadDocument,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: driverState?.isLoading == true
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Upload',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }
}
