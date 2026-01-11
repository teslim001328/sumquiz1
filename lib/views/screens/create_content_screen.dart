
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  final _textController = TextEditingController();
  final _linkController = TextEditingController();
  String? _pdfName;
  Uint8List? _pdfBytes;
  String? _imageName;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String _errorMessage = '';

  final ImagePicker _imagePicker = ImagePicker();

  // Clears all input fields and resets the state
  void _resetInputs() {
    _textController.clear();
    _linkController.clear();
    setState(() {
      _pdfName = null;
      _pdfBytes = null;
      _imageName = null;
      _imageBytes = null;
      _errorMessage = '';
    });
  }

  // These methods will set the active input type and clear others
  void _activateTextField() {
    if (_linkController.text.isNotEmpty || _pdfBytes != null || _imageBytes != null) {
      _resetInputs();
    }
  }

  void _activateLinkField() {
     if (_textController.text.isNotEmpty || _pdfBytes != null || _imageBytes != null) {
      _resetInputs();
    }
  }


  bool _checkProAccess(String feature) {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user != null && !user.isPro) {
      showDialog(
        context: context,
        builder: (_) => UpgradeDialog(featureName: feature),
      );
      return false;
    }
    return true;
  }

  Future<void> _pickPdf() async {
    if (!_checkProAccess('PDF Upload')) return;
    _resetInputs(); // Clear other inputs
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _pdfName = result.files.single.name;
          _pdfBytes = result.files.single.bytes;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error picking PDF: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_checkProAccess('Image Scan')) return;
    _resetInputs(); // Clear other inputs
    try {
      final XFile? image = await _imagePicker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageName = image.name;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error picking image: $e');
    }
  }

  Future<void> _processAndNavigate() async {
    if (_isLoading) return;

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      setState(() => _errorMessage = 'You must be logged in to create content.');
      return;
    }

    final usageService = UsageService();
    final canGenerate = await usageService.canGenerateDeck(user.uid);

    if (!canGenerate) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => const UpgradeDialog(featureName: 'Daily Limit'),
        );
      }
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final extractionService = Provider.of<ContentExtractionService>(context, listen: false);
      String extractedText = '';
      
      // Determine which input is active and process it
      if (_textController.text.trim().isNotEmpty) {
        extractedText = _textController.text;
      } else if (_linkController.text.trim().isNotEmpty) {
        if (!_checkProAccess('Web Link')) {
           setState(() => _isLoading = false);
           return;
        }
        extractedText = await extractionService.extractContent(type: 'link', input: _linkController.text);
      } else if (_pdfBytes != null) {
        extractedText = await extractionService.extractContent(type: 'pdf', input: _pdfBytes!);
      } else if (_imageBytes != null) {
        extractedText = await extractionService.extractContent(type: 'image', input: _imageBytes!);
      } else {
        throw Exception('Please provide some content first.');
      }
      
      if (extractedText.trim().isEmpty) {
        throw Exception('Could not extract any content from the source.');
      }

      await usageService.recordDeckGeneration(user.uid);

      if (mounted) {
        context.push('/create/extraction-view', extra: extractedText);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Create Content', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Icon(Icons.person, color: colorScheme.onSurfaceVariant, size: 20),
            ),
            onPressed: () => context.push('/account'),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: theme.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: theme.textTheme.displaySmall?.copyWith(color: colorScheme.onSurface, height: 1.3),
                children: [
                  const TextSpan(text: 'What do you want to '),
                  TextSpan(text: 'learn', style: TextStyle(color: colorScheme.primary)),
                  const TextSpan(text: ' today?'),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildSectionHeader(colorScheme, Icons.edit, 'PASTE TEXT'),
            _buildPasteTextSection(theme),
            const SizedBox(height: 32),
            _buildSectionHeader(colorScheme, Icons.link, 'IMPORT WEBPAGE'),
            _buildImportWebpageSection(theme),
            const SizedBox(height: 32),
            _buildSectionHeader(colorScheme, Icons.picture_as_pdf, 'UPLOAD PDF'),
            _buildUploadPdfSection(theme),
            const SizedBox(height: 32),
            _buildSectionHeader(colorScheme, Icons.fullscreen, 'SCAN IMAGE'),
            _buildScanImageSection(theme),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 24),
              Center(child: Text(_errorMessage, style: TextStyle(color: colorScheme.error, fontSize: 14))),
            ],
            const SizedBox(height: 120), // Space for the floating button
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildProcessButton(theme),
    );
  }

  Widget _buildSectionHeader(ColorScheme colorScheme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildPasteTextSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          TextField(
            controller: _textController,
            maxLines: 5,
            onTap: _activateTextField,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            decoration: InputDecoration(
              hintText: 'Type or paste your notes here for AI summary...',
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data != null) {
                  _activateTextField();
                  _textController.text = data.text ?? '';
                }
              },
              icon: Icon(Icons.paste, size: 16, color: theme.colorScheme.onSecondaryContainer),
              label: Text('Paste', style: TextStyle(color: theme.colorScheme.onSecondaryContainer)),
              style: TextButton.styleFrom(
                backgroundColor: theme.colorScheme.secondaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportWebpageSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.public, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _linkController,
              onTap: _activateLinkField,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              decoration: InputDecoration(
                hintText: 'https://example.com/article',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPdfSection(ThemeData theme) {
    final bool isSelected = _pdfBytes != null;
    return GestureDetector(
      onTap: _pickPdf,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 1 : 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: isSelected ? theme.colorScheme.primary.withOpacity(0.2) : theme.colorScheme.surfaceContainerHighest,
              radius: 24,
              child: Icon(
                isSelected ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _pdfName ?? 'Tap to browse',
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isSelected)
              Text('PDF files up to 10MB', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildScanImageSection(ThemeData theme) {
    final bool isCameraSelected = _imageBytes != null && _imageName?.contains('camera') == true;
    final bool isGallerySelected = _imageBytes != null && _imageName?.contains('gallery') == true;

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        children: [
          Expanded(child: _buildScanButton('Camera', Icons.camera_alt, () => _pickImage(ImageSource.camera), isCameraSelected, theme)),
          const SizedBox(width: 16),
          Expanded(child: _buildScanButton('Gallery', Icons.photo_library, () => _pickImage(ImageSource.gallery), isGallerySelected, theme)),
        ],
      ),
    );
  }

  Widget _buildScanButton(String label, IconData icon, VoidCallback onPressed, bool isSelected, ThemeData theme) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: isSelected ? theme.colorScheme.primary.withOpacity(0.2) : theme.colorScheme.secondaryContainer,
              radius: 24,
              child: Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSecondaryContainer, size: 24),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _processAndNavigate,
          icon: _isLoading
              ? Container(
                  width: 24,
                  height: 24,
                  padding: const EdgeInsets.all(2.0),
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.onPrimary,
                    strokeWidth: 3,
                  ),
                )
              : Icon(Icons.auto_awesome_sharp, color: theme.colorScheme.onPrimary, size: 20),
          label: Text(
            'Extract Content',
            style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            disabledBackgroundColor: theme.colorScheme.primary.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
        ),
      ),
    );
  }
}
