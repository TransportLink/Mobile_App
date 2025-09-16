import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'upload_document_screen.dart';

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({super.key});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  final AuthService _authService = AuthService();
  List<dynamic> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    final result = await _authService.listDocuments();
    setState(() {
      if (result['success']) {
        _documents = result['data'];
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Error fetching documents')),
        );
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Documents'),
        backgroundColor: Colors.indigo,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(child: Text('No documents found', style: TextStyle(color: Colors.white)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final document = _documents[index];
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        leading: document['document_file_url'] != null
                            ? Image.network(document['document_file_url'], width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.description, size: 50, color: Colors.indigo),
                        title: Text(document['document_type'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Number: ${document['document_number'] ?? 'Not set'}'),
                            Text('Status: ${document['status'] ?? 'Not set'}'),
                            Text('Expiry: ${document['expiry_date'] ?? 'Not set'}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const UploadDocumentScreen(),
            ),
          ).then((_) => _fetchDocuments());
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        child: const Icon(Icons.add),
      ),
    );
  }
}