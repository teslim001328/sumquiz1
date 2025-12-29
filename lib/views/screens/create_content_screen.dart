import 'dart:math';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

import '../../models/user_model.dart';

// Enum to represent the single source of content
enum ContentType { text, link, pdf, image }

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  // State variables
  ContentType? _activeContentType;
  final _textController = TextEditingController();
  final _linkController = TextEditingController();
  String? _pdfName;
  Uint8List? _pdfBytes;
  String? _imageName;
  Uint8List? _imageBytes;

  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    _textController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  // Reset all other inputs when one is activated
  void _resetInputs({ContentType? except}) {
    if (except != ContentType.text) _textController.clear();
    if (except != ContentType.link) _linkController.clear();
    if (except != ContentType.pdf) {
      _pdfName = null;
      _pdfBytes = null;
    }
    if (except != ContentType.image) {
      _imageName = null;
      _imageBytes = null;
    }
    _activeContentType = except;
  }

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) {
      setState(() {
        _resetInputs(except: ContentType.pdf);
        _pdfName = result.files.single.name;
        _pdfBytes = result.files.single.bytes;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(source: source);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _resetInputs(except: ContentType.image);
        _imageName = image.name;
        _imageBytes = bytes;
      });
    }
  }

  void _processAndNavigate() async {
    if (_activeContentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide some content first.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create content.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    String source;
    String title;

    try {
      switch (_activeContentType!) {
        case ContentType.text:
          if (_textController.text.trim().isEmpty) {
            throw Exception('The text field is empty.');
          }
          source = _textController.text;
          title = _textController.text.substring(0, min(_textController.text.length, 50));
          break;
        case ContentType.link:
          if (_linkController.text.trim().isEmpty) {
            throw Exception('The URL field is empty.');
          }
          source = _linkController.text;
          title = _linkController.text;
          break;
        case ContentType.pdf:
          if (_pdfBytes == null) {
            throw Exception('No PDF file was selected.');
          }
          source = await ContentExtractionService.extractFromPdfBytes(_pdfBytes!);
          title = _pdfName ?? 'PDF Document';
          break;
        case ContentType.image:
          if (_imageBytes == null) {
            throw Exception('No image was selected.');
          }
          source = await ContentExtractionService.extractFromImageBytes(_imageBytes!);
          title = _imageName ?? 'Image';
          break;
      }

      final aiService = Provider.of<AIService>(context, listen: false);
      final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
      final contentExtractionService = ContentExtractionService(aiService, localDb);

      final folderId = await contentExtractionService.extractAndGenerate(
          source, title, ['summary', 'quiz', 'flashcards'], user.uid);

      if (mounted) {
        context.push('/results-view/$folderId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process content: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Content'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             RichText(
              text: TextSpan(
                style: theme.textTheme.headlineMedium,
                children: [
                  const TextSpan(text: 'What do you want to '),
                  TextSpan(text: 'learn', style: TextStyle(color: theme.colorScheme.secondary)),
                  const TextSpan(text: ' today?'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('PASTE TEXT', Icons.edit),
            _buildPasteTextSection(),
            const SizedBox(height: 32),
            _buildSectionHeader('IMPORT WEBPAGE', Icons.link),
            _buildImportWebpageSection(),
            const SizedBox(height: 32),
            _buildSectionHeader('UPLOAD PDF', Icons.picture_as_pdf),
            _buildUploadPdfSection(),
            const SizedBox(height: 32),
            _buildSectionHeader('SCAN IMAGE', Icons.fullscreen),
            _buildScanImageSection(),
            const SizedBox(height: 100), // Extra space for FAB
          ],
        ),
      ),
      floatingActionButton: _buildGenerateButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.secondary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildPasteTextSection() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      height: 150,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onTap: () => setState(() => _resetInputs(except: ContentType.text)),
        controller: _textController,
        maxLines: null,
        expands: true,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Type or paste your notes here for AI summary...',
          hintStyle: theme.textTheme.bodySmall,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildImportWebpageSection() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.public, color: theme.iconTheme.color),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onTap: () => setState(() => _resetInputs(except: ContentType.link)),
              controller: _linkController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'https://example.com/article',
                hintStyle: theme.textTheme.bodySmall,
                border: InputBorder.none,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => setState(() => _activeContentType = ContentType.link),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Add', style: TextStyle(color: theme.colorScheme.onSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPdfSection() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _pickPdf,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor, width: 1, style: BorderStyle.solid),
        ),
        child: _pdfName == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file, color: theme.colorScheme.secondary, size: 36),
                  const SizedBox(height: 8),
                  Text('Tap to browse', style: theme.textTheme.bodyMedium),
                  Text('PDF files up to 10MB', style: theme.textTheme.bodySmall),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.secondary, size: 36),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(_pdfName!, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildScanImageSection() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: _buildScanButton('Camera', Icons.camera_alt, () => _pickImage(ImageSource.camera))),
          const SizedBox(width: 16),
          Expanded(child: _buildScanButton('Gallery', Icons.photo_library, () => _pickImage(ImageSource.gallery))),
        ],
      ),
    );
  }

  Widget _buildScanButton(String label, IconData icon, VoidCallback onPressed) {
    final theme = Theme.of(context);
    bool isSelected = _activeContentType == ContentType.image && _imageName != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? Icons.check_circle : icon, color: theme.colorScheme.secondary, size: 36),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(isSelected ? _imageName! : label, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _processAndNavigate,
          icon: _isLoading
              ? const SizedBox.shrink()
              : Icon(Icons.double_arrow_rounded, color: theme.colorScheme.onSecondary),
          label: _isLoading
              ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onSecondary))
              : Text('Extract Content', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSecondary)),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
        ),
      ),
    );
  }
}
