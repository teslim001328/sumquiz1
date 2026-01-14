import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/views/widgets/extraction_progress_dialog.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';

class InputValidator {
  static bool isValidUrl(String url) {
    if (url.trim().isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  static bool isYoutubeUrl(String url) {
    return url.contains('youtube.com/watch') ||
        url.contains('youtu.be/') ||
        url.contains('youtube.com/shorts/');
  }

  static String? validateText(String text) {
    if (text.trim().isEmpty) {
      return 'Please enter some text';
    }
    if (text.trim().length < 50) {
      return 'Text is too short. Please provide at least 50 characters';
    }
    if (text.length > 50000) {
      return 'Text is too long. Maximum 50,000 characters';
    }
    return null; // Valid
  }

  static String? validateUrl(String url) {
    if (url.trim().isEmpty) {
      return 'Please enter a URL';
    }
    if (!isValidUrl(url)) {
      return 'Please enter a valid URL (must start with http:// or https://)';
    }
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      if (!isYoutubeUrl(url)) {
        return 'Invalid YouTube URL. Please provide a valid video, short, or live stream link.';
      }
    }
    return null; // Valid
  }
}

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
    if (_linkController.text.isNotEmpty ||
        _pdfBytes != null ||
        _imageBytes != null) {
      _resetInputs();
    }
  }

  void _activateLinkField() {
    if (_textController.text.isNotEmpty ||
        _pdfBytes != null ||
        _imageBytes != null) {
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
      final XFile? image =
          await _imagePicker.pickImage(source: source, imageQuality: 80);
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
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      setState(
          () => _errorMessage = 'You must be logged in to create content.');
      return;
    }

    // Validate input
    String? validationError;
    String type;
    dynamic input;

    if (_textController.text.trim().isNotEmpty) {
      validationError = InputValidator.validateText(_textController.text);
      type = 'text';
      input = _textController.text;
    } else if (_linkController.text.trim().isNotEmpty) {
      validationError = InputValidator.validateUrl(_linkController.text);
      type = 'link';
      input = _linkController.text;
    } else if (_pdfBytes != null) {
      if (_pdfBytes!.length > 15 * 1024 * 1024) {
        validationError = 'PDF file is too large. Maximum size is 15MB';
      }
      type = 'pdf';
      input = _pdfBytes;
    } else if (_imageBytes != null) {
      if (_imageBytes!.length > 10 * 1024 * 1024) {
        validationError = 'Image file is too large. Maximum size is 10MB';
      }
      type = 'image';
      input = _imageBytes;
    } else {
      validationError = 'Please provide some content to process';
      type = '';
      input = null;
    }

    if (validationError != null) {
      setState(() => _errorMessage = validationError!);
      return;
    }

    final extractionService =
        Provider.of<ContentExtractionService>(context, listen: false);

    // Capture the navigator before showing dialog to avoid context issues
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const ExtractionProgressDialog();
      },
    );

    try {
      final extractedTextResult = await extractionService.extractContent(
        type: type,
        input: input,
        userId: user.uid,
      );
      if (mounted) {
        // Safely close dialog using captured navigator
        try {
          navigator.pop();
        } catch (e) {
          // Dialog already closed or context invalid, ignore
        }
        context.push('/create/extraction-view', extra: extractedTextResult);
      }
    } catch (e) {
      if (mounted) {
        // Safely close dialog using captured navigator
        try {
          navigator.pop();
        } catch (e) {
          // Dialog already closed or context invalid, ignore
        }
        setState(() {
          _errorMessage = _getUserFriendlyError(e);
        });
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
        title: Text('Create Content',
            style: TextStyle(
                color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Icon(Icons.person,
                  color: colorScheme.onSurfaceVariant, size: 20),
            ),
            onPressed: () => context.push('/account'),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: theme.textTheme.displaySmall
                    ?.copyWith(color: colorScheme.onSurface, height: 1.3),
                children: [
                  const TextSpan(text: 'What do you want to '),
                  TextSpan(
                      text: 'learn',
                      style: TextStyle(color: colorScheme.primary)),
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
            _buildSectionHeader(
                colorScheme, Icons.picture_as_pdf, 'UPLOAD PDF'),
            _buildUploadPdfSection(theme),
            const SizedBox(height: 32),
            _buildSectionHeader(colorScheme, Icons.fullscreen, 'SCAN IMAGE'),
            _buildScanImageSection(theme),
            _buildErrorDisplay(theme),
            const SizedBox(height: 120), // Space for the floating button
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildProcessButton(theme),
    );
  }

  Widget _buildSectionHeader(
      ColorScheme colorScheme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildPasteTextSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(77)),
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
              hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(128)),
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
              icon: Icon(Icons.paste,
                  size: 16, color: theme.colorScheme.onSecondaryContainer),
              label: Text('Paste',
                  style:
                      TextStyle(color: theme.colorScheme.onSecondaryContainer)),
              style: TextButton.styleFrom(
                backgroundColor: theme.colorScheme.secondaryContainer,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportWebpageSection(ThemeData theme) {
    final isValid = _linkController.text.isNotEmpty &&
        InputValidator.isValidUrl(_linkController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _linkController.text.isEmpty
                  ? theme.colorScheme.outline.withAlpha(77)
                  : isValid
                      ? Colors.green.withAlpha(128)
                      : Colors.red.withAlpha(128),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.link,
                color: _linkController.text.isEmpty
                    ? theme.colorScheme.onSurfaceVariant.withAlpha(178)
                    : isValid
                        ? Colors.green
                        : Colors.red,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _linkController,
                  onTap: _activateLinkField,
                  onChanged: (value) =>
                      setState(() {}), // Trigger rebuild for validation
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  decoration: InputDecoration(
                    hintText: 'YouTube, article, PDF link, or any URL',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                    ),
                    border: InputBorder.none,
                    suffixIcon: _linkController.text.isNotEmpty
                        ? Icon(
                            isValid ? Icons.check_circle : Icons.error,
                            color: isValid ? Colors.green : Colors.red,
                            size: 20,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, right: 16),
          child: Text(
            '💡 Paste links to YouTube videos, articles, PDFs, images, audio, or video files',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
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
          color: isSelected
              ? theme.colorScheme.primaryContainer.withAlpha(77)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withAlpha(77),
            width: isSelected ? 1 : 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: isSelected
                  ? theme.colorScheme.primary.withAlpha(51)
                  : theme.colorScheme.surfaceContainerHighest,
              radius: 24,
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _pdfName ?? 'Tap to browse',
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isSelected)
              Text('PDF files up to 10MB',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(153),
                      fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildScanImageSection(ThemeData theme) {
    final bool isCameraSelected =
        _imageBytes != null && _imageName?.contains('camera') == true;
    final bool isGallerySelected =
        _imageBytes != null && _imageName?.contains('gallery') == true;

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        children: [
          Expanded(
              child: _buildScanButton(
                  'Camera',
                  Icons.camera_alt,
                  () => _pickImage(ImageSource.camera),
                  isCameraSelected,
                  theme)),
          const SizedBox(width: 16),
          Expanded(
              child: _buildScanButton(
                  'Gallery',
                  Icons.photo_library,
                  () => _pickImage(ImageSource.gallery),
                  isGallerySelected,
                  theme)),
        ],
      ),
    );
  }

  Widget _buildScanButton(String label, IconData icon, VoidCallback onPressed,
      bool isSelected, ThemeData theme) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withAlpha(77)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: isSelected
                  ? theme.colorScheme.primary.withAlpha(51)
                  : theme.colorScheme.secondaryContainer,
              radius: 24,
              child: Icon(icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSecondaryContainer,
                  size: 24),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold)),
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
          onPressed: _processAndNavigate,
          icon: Icon(Icons.auto_awesome_sharp,
              color: theme.colorScheme.onPrimary, size: 20),
          label: Text(
            'Extract Content',
            style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            disabledBackgroundColor: theme.colorScheme.primary.withAlpha(128),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
        ),
      ),
    );
  }

  String _getUserFriendlyError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Network errors
    if (errorStr.contains('socket') ||
        errorStr.contains('network') ||
        errorStr.contains('connection')) {
      return '📡 Check your internet connection and try again';
    }

    // Timeout errors
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return '⏱️ Request took too long. Try with shorter content or check your connection';
    }

    // Rate limit errors
    if (errorStr.contains('rate limit')) {
      return '🚦 Too many requests. Please wait a few minutes before trying again';
    }

    // API errors
    if (errorStr.contains('api') || errorStr.contains('quota')) {
      return '🔑 Service temporarily unavailable. Please try again later';
    }

    // Content too long
    if (errorStr.contains('too long') || errorStr.contains('maximum')) {
      return '📏 Content is too long. Try breaking it into smaller sections';
    }

    // YouTube specific
    if (errorStr.contains('youtube') || errorStr.contains('video')) {
      if (errorStr.contains('quota') ||
          errorStr.contains('limit') ||
          errorStr.contains('daily')) {
        return '🎥 Daily YouTube analysis limit reached (free tier: 8 hours/day). Try again tomorrow';
      }
      if (errorStr.contains('unavailable') ||
          errorStr.contains('private') ||
          errorStr.contains('removed')) {
        return '🎥 Video is unavailable, private, or has been removed. Try a different video';
      }
      if (errorStr.contains('age-restricted') ||
          errorStr.contains('access') ||
          errorStr.contains('permission')) {
        return '🔞 Cannot access age-restricted or private videos. Try a public video';
      }
      if (errorStr.contains('timeout') || errorStr.contains('too long')) {
        return '⏱️ Video is too long to process (max ~45 min with audio). Try a shorter video';
      }
      if (errorStr.contains('invalid') || errorStr.contains('format')) {
        return '🎥 Invalid YouTube URL. Use format: https://youtube.com/watch?v=VIDEO_ID';
      }
      if (errorStr.contains('caption') || errorStr.contains('transcript')) {
        return '📝 Video doesn\'t have captions. Try a video with subtitles enabled';
      }
      return '🎥 Could not process video. Make sure it\'s a public YouTube video and try again';
    }

    // PDF errors
    if (errorStr.contains('pdf')) {
      if (errorStr.contains('size') || errorStr.contains('large')) {
        return '📄 PDF file is too large. Maximum size is 15MB';
      }
      return '📄 Could not read PDF. Make sure the file isn\'t corrupted';
    }

    // Image errors
    if (errorStr.contains('image') || errorStr.contains('ocr')) {
      return '🖼️ Could not read text from image. Try a clearer image with better lighting';
    }

    // Auth/permission errors
    if (errorStr.contains('permission') || errorStr.contains('unauthorized')) {
      return '🔒 Access denied. Please log in and try again';
    }

    // Limit errors
    if (errorStr.contains('limit reached') || errorStr.contains('upgrade')) {
      return error.toString().replaceFirst('Exception: ', '');
    }

    // AI generation errors
    if (error is EnhancedAIServiceException) {
      return '🤖 ${error.message}';
    }

    // Extraction errors
    if (error is Exception) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.length < 100) {
        return '⚠️ $message';
      }
    }

    // Generic fallback
    return '❌ Something went wrong. Please try again or contact support';
  }

  Widget _buildErrorDisplay(ThemeData theme) {
    if (_errorMessage.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withAlpha(77),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _errorMessage = ''),
            color: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }
}
