import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobileapp/features/driver/utils/driver_utils.dart';
import 'package:mobileapp/features/driver/viewmodel/driver_view_model.dart';

class DriverDocumentsPage extends ConsumerStatefulWidget {
  const DriverDocumentsPage({super.key});

  @override
  ConsumerState<DriverDocumentsPage> createState() => _DriverDocumentsPageState();
}

class _DriverDocumentsPageState extends ConsumerState<DriverDocumentsPage> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadModalOpen = false;

  final _documentTypeController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  File? _selectedDocument;

  final List<String> _documentTypes = [
    'Driver License',
    'Vehicle Registration',
    'Insurance Certificate',
    'Vehicle Inspection',
    'National ID',
    'Medical Certificate',
    'Police Clearance',
  ];

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
    if (_documentTypeController.text.isEmpty ||
        _documentNumberController.text.isEmpty ||
        _expiryDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    await ref.read(driverViewModelProvider.notifier).uploadDocument(
      documentType: _documentTypeController.text,
      documentNumber: _documentNumberController.text,
      expiryDate: _expiryDateController.text,
      documentPath: _selectedDocument?.path,
    );

    if (mounted) {
      _closeUploadModal();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded successfully'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  void _openUploadModal() {
    setState(() {
      _isUploadModalOpen = true;
      _documentTypeController.clear();
      _documentNumberController.clear();
      _expiryDateController.clear();
      _selectedDocument = null;
    });
  }

  void _closeUploadModal() {
    setState(() {
      _isUploadModalOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Documents',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openUploadModal,
            icon: const Icon(Icons.add, color: Colors.black),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(),
                const SizedBox(height: 24),
                _buildDocumentsList(driverState),
              ],
            ),
          ),
          
          if (_isUploadModalOpen) _buildUploadModal(driverState),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openUploadModal,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Document Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Keep your documents up to date',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(AsyncValue<Map<String, dynamic>>? driverState) {
    if (driverState?.isLoading == true) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.black,
          ),
        ),
      );
    }

    if (driverState?.hasError == true) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.black26,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading documents',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                driverState!.error.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black38,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // sample data for now
    final documents = getSampleDocuments();

    if (documents.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.description_outlined,
                size: 64,
                color: Colors.black26,
              ),
              const SizedBox(height: 16),
              const Text(
                'No documents uploaded',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload your first document to get started',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black38,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _openUploadModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Upload Document',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.separated(
        itemCount: documents.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final document = documents[index];
          return _buildDocumentCard(document);
        },
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    final isExpired = isDocumentExpired(document['expiryDate']);
    final isExpiringSoon = isDocumentExpiringSoon(document['expiryDate']);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired 
              ? const Color.fromARGB(255, 248, 78, 78)
              : isExpiringSoon 
                  ? const Color.fromARGB(255, 255, 193, 100)
                  : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isExpired 
                      ? Colors.red.shade50
                      : isExpiringSoon 
                          ? Colors.orange.shade50
                          : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  getDocumentIcon(document['type']),
                  color: isExpired 
                      ? Colors.red.shade600
                      : isExpiringSoon 
                          ? Colors.orange.shade600
                          : Colors.black54,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document['type'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      document['number'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(document['expiryDate']),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Colors.black38,
              ),
              const SizedBox(width: 8),
              Text(
                'Expires: ${document['expiryDate']}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Handle view document
                },
                child: const Text(
                  'View',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String expiryDate) {
    if (isDocumentExpired(expiryDate)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          'Expired',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.red.shade700,
          ),
        ),
      );
    } else if (isDocumentExpiringSoon(expiryDate)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Text(
          'Expiring Soon',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.orange.shade700,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Text(
          'Valid',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.green.shade700,
          ),
        ),
      );
    }
  }

  Widget _buildUploadModal(AsyncValue<Map<String, dynamic>>? driverState) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                      onPressed: _closeUploadModal,
                      icon: const Icon(Icons.close, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Document Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _documentTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    _documentTypeController.text = value ?? '';
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _documentNumberController,
                  decoration: InputDecoration(
                    labelText: 'Document Number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _expiryDateController,
                  readOnly: true,
                  onTap: _selectExpiryDate,
                  decoration: InputDecoration(
                    labelText: 'Expiry Date',
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _pickDocument,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12, style: BorderStyle.solid),
                    ),
                    child: _selectedDocument != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _selectedDocument!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedDocument = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 48,
                                color: Colors.black26,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to upload document',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _closeUploadModal,
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
                        onPressed: driverState?.isLoading == true
                            ? null
                            : _uploadDocument,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}