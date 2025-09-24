import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobileapp/core/model/driver_document.dart';
import 'package:mobileapp/core/widgets/loader.dart';
import 'package:mobileapp/features/driver/viewmodel/driver_view_model.dart';
import 'package:mobileapp/features/driver/widgets/document_widgets.dart';
import 'package:mobileapp/features/driver/widgets/upload_document_modal.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverDocumentsPage extends ConsumerStatefulWidget {
  const DriverDocumentsPage({super.key});

  @override
  ConsumerState<DriverDocumentsPage> createState() =>
      _DriverDocumentsPageState();
}

class _DriverDocumentsPageState extends ConsumerState<DriverDocumentsPage> {
  bool _isUploadModalOpen = false;

  void _openUploadModal() {
    setState(() {
      _isUploadModalOpen = true;
    });
  }

  void _closeUploadModal() {
    setState(() {
      _isUploadModalOpen = false;
    });
  }

  Future _onViewDocument(DriverDocument document) async {
    final String url = document.document_file_url;
    final Uri uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing ${document.document_type}'),
        backgroundColor: Colors.black,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildMainContent(),
          if (_isUploadModalOpen) _buildUploadModal(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
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
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DocumentWidgets.buildStatusHeader(),
          const SizedBox(height: 24),
          Expanded(child: _buildDocumentsList()),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    return Consumer(
      builder: (context, ref, child) {
        final documentsAsync = ref.watch(getAllDocumentsProvider);

        return documentsAsync.when(
          data: (documents) {
            if (documents.isEmpty) {
              return DocumentWidgets.buildEmptyState(_openUploadModal);
            }

            return ListView.separated(
              itemCount: documents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final document = documents[index];
                return DocumentWidgets.buildDocumentCard(
                  document,
                  onViewPressed: () => _onViewDocument(document),
                );
              },
            );
          },
          error: (error, stackTrace) {
            return DocumentWidgets.buildErrorState(error.toString());
          },
          loading: () => const Center(child: Loader()),
        );
      },
    );
  }

  Widget _buildUploadModal() {
    return UploadDocumentModal(
      onClose: _closeUploadModal,
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _openUploadModal,
      backgroundColor: Colors.black,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}
