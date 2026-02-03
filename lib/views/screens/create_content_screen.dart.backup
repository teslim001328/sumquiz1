import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
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

class _CreateContentScreenState extends State<CreateContentScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _linkController = TextEditingController();
  final _topicController = TextEditingController();
  String? _pdfName;
  Uint8List? _pdfBytes;
  String? _imageName;
  Uint8List? _imageBytes;
  String _errorMessage = '';

  // Topic-based learning state
  String _topicDepth = 'intermediate';
  double _topicCardCount = 15;

  final ImagePicker _imagePicker = ImagePicker();
  String _selectedImportMethod = '';

  // Loading and state management
  bool _isLoading = false;
  bool _isProcessing = false;
  String _currentOperation = '';

  // Cancellation tokens
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _isCancelled = true;
    _textController.dispose();
    _linkController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  void _resetInputs() {
    _textController.clear();
    _linkController.clear();
    _topicController.clear();
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
    if (_isLoading || _isProcessing) return;

    if (!_checkProAccess('PDF Upload')) return;
    _resetInputs(); // Clear other inputs

    setState(() => _isLoading = true);

    try {
      // Determine allowed extensions based on selected method
      List<String> allowedTypes;
      String fileTypeDescription;
      int maxSizeMb;

      if (_selectedImportMethod == 'slides') {
        allowedTypes = ['pdf', 'ppt', 'pptx', 'odp'];
        fileTypeDescription = 'slides';
        maxSizeMb = 15;
      } else {
        allowedTypes = ['pdf'];
        fileTypeDescription = 'PDF';
        maxSizeMb = 15;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedTypes,
        withData: true,
      );

      if (result != null) {
        if (result.files.isEmpty) {
          throw Exception('No file selected');
        }

        final file = result.files.single;

        if (file.bytes == null) {
          throw Exception('Failed to read file data');
        }

        // Validate file size
        final fileSizeMb = file.bytes!.length / (1024 * 1024);
        if (fileSizeMb > maxSizeMb) {
          throw Exception(
              '${fileTypeDescription.toUpperCase()} file is too large. Maximum size is ${maxSizeMb}MB. Selected file is ${fileSizeMb.toStringAsFixed(1)}MB');
        }

        // Validate file extension
        final fileExtension = file.extension?.toLowerCase();
        if (fileExtension == null || !allowedTypes.contains(fileExtension)) {
          throw Exception(
              'Invalid file type. Supported formats: ${allowedTypes.join(', ').toUpperCase()}');
        }

        setState(() {
          _pdfName = file.name;
          _pdfBytes = file.bytes;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = _getUserFriendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading || _isProcessing) return;

    if (!_checkProAccess('Image Scan')) return;
    _resetInputs(); // Clear other inputs

    setState(() => _isLoading = true);

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxHeight: 1920,
        maxWidth: 1920,
      );

      if (image != null) {
        // Validate file size (10MB limit)
        final fileStat = await image.length();
        final fileSizeMb = fileStat / (1024 * 1024);
        if (fileSizeMb > 10) {
          throw Exception(
              'Image file is too large. Maximum size is 10MB. Selected image is ${fileSizeMb.toStringAsFixed(1)}MB');
        }

        final bytes = await image.readAsBytes();

        // Validate that we got data
        if (bytes.isEmpty) {
          throw Exception('Failed to read image data');
        }

        setState(() {
          _imageName =
              '${source == ImageSource.camera ? "camera_" : "gallery_"}${image.name}';
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = _getUserFriendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processAndNavigate() async {
    // Prevent multiple concurrent operations
    if (_isProcessing || _isLoading) return;

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      setState(
          () => _errorMessage = 'You must be logged in to create content.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = '';
      _currentOperation = 'Initializing...';
    });

    try {
      // Check if topic generation is selected
      if (_topicController.text.trim().isNotEmpty) {
        await _processTopicGeneration(user);
        return;
      }

      // Otherwise, process import method
      String? validationError;
      String type;
      dynamic input;

      switch (_selectedImportMethod) {
        case 'text':
          validationError = InputValidator.validateText(_textController.text);
          type = 'text';
          input = _textController.text;
          break;
        case 'link':
          validationError = InputValidator.validateUrl(_linkController.text);
          type = 'link';
          input = _linkController.text;
          break;
        case 'pdf':
          if (_pdfBytes == null) {
            validationError = 'Please upload a PDF file';
          } else if (_pdfBytes!.length > 15 * 1024 * 1024) {
            validationError = 'PDF file is too large. Maximum size is 15MB';
          }
          type = 'pdf';
          input = _pdfBytes;
          break;
        case 'image':
          if (_imageBytes == null) {
            validationError = 'Please capture or select an image';
          } else if (_imageBytes!.length > 10 * 1024 * 1024) {
            validationError = 'Image file is too large. Maximum size is 10MB';
          }
          type = 'image';
          input = _imageBytes;
          break;
        case 'slides':
          if (_pdfBytes == null) {
            validationError = 'Please upload a slides file';
          } else if (_pdfBytes!.length > 15 * 1024 * 1024) {
            validationError = 'Slides file is too large. Maximum size is 15MB';
          }
          type = 'slides';
          input = _pdfBytes;
          break;
        default:
          validationError = 'Please select an import method';
          type = '';
          input = null;
      }

      if (validationError != null) {
        setState(() => _errorMessage = validationError!);
        return;
      }

      await _processContentExtraction(type, input, user);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _currentOperation = '';
        });
      }
    }
  }

  Future<void> _processContentExtraction(
      String type, dynamic input, UserModel user) async {
    if (_isCancelled) return;

    final extractionService =
        Provider.of<ContentExtractionService>(context, listen: false);

    // Track progress for the dialog
    final progressNotifier =
        ValueNotifier<String>('Preparing to extract content...');

    // Capture the navigator before showing dialog to avoid context issues
    final navigator = Navigator.of(context);

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return WillPopScope(
            onWillPop: () async {
              // Allow cancellation
              _isCancelled = true;
              return true;
            },
            child: ExtractionProgressDialog(messageNotifier: progressNotifier),
          );
        },
      );
    }

    try {
      final ExtractionResult extractionResult =
          await extractionService.extractContent(
        type: type,
        input: input,
        userId: user.uid,
        onProgress: (message) {
          if (!_isCancelled && mounted) {
            progressNotifier.value = message;
          }
        },
      );

      if (!_isCancelled && mounted) {
        // Safely close dialog
        try {
          navigator.pop();
        } catch (e) {
          // Dialog already closed or context invalid, ignore
        }

        // Reset state and navigate
        _resetInputs();
        context.push('/create/extraction-view', extra: extractionResult);
      }
    } on Exception catch (e) {
      if (!_isCancelled && mounted) {
        // Safely close dialog
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
    final user = Provider.of<UserModel?>(context);

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
      body: Column(
        children: [
          // Professional Welcome Header
          _buildWelcomeHeader(theme, colorScheme, user),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildUnifiedImportGrid(theme, colorScheme),
                  const SizedBox(height: 24),
                  _buildActiveImportSection(theme),
                  _buildErrorDisplay(theme),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildProcessButton(theme),
    );
  }

  Widget _buildWelcomeHeader(
      ThemeData theme, ColorScheme colorScheme, UserModel? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              children: [
                const TextSpan(text: 'What will you '),
                TextSpan(
                  text: 'master',
                  style: TextStyle(color: colorScheme.primary),
                ),
                const TextSpan(text: ' today?'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create study goals in seconds',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedImportGrid(ThemeData theme, ColorScheme colorScheme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildQuickTopicCard(theme, colorScheme),
        _buildImportCard(
            'Scan PDF', Icons.picture_as_pdf_rounded, 'pdf', colorScheme),
        _buildImportCard('Link/Video', Icons.link_rounded, 'link', colorScheme),
        _buildImportCard(
            'Paste Text', Icons.text_fields_rounded, 'text', colorScheme),
        _buildImportCard(
            'Scan Image', Icons.camera_alt_rounded, 'image', colorScheme),
        _buildImportCard(
            'Upload Slides', Icons.slideshow_rounded, 'slides', colorScheme),
      ],
    );
  }

  Widget _buildQuickTopicCard(ThemeData theme, ColorScheme colorScheme) {
    final isSelected = _topicController.text.trim().isNotEmpty;
    final isDisabled = _isProcessing || _isLoading;

    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: GestureDetector(
          onTap: () {
            if (isDisabled) return;

            setState(() {
              _selectedImportMethod = '';
              if (!isSelected) {
                // Clear other inputs when selecting topic
                _resetInputs();
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
                    size: 28),
                const SizedBox(height: 8),
                Text(
                  'Quick Topic',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI Generated',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? colorScheme.onPrimary.withValues(alpha: 0.8)
                        : colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                if (isDisabled) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportCard(
      String label, IconData icon, String method, ColorScheme colorScheme) {
    final isSelected = _selectedImportMethod == method;
    final isDisabled = _isProcessing || _isLoading;

    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: GestureDetector(
          onTap: () {
            if (isDisabled) return;

            if (method == 'link' ||
                method == 'pdf' ||
                method == 'image' ||
                method == 'slides') {
              // Check Pro for advanced inputs
              String featureName = '';
              if (method == 'link') featureName = 'Web/YouTube Analysis';
              if (method == 'pdf') featureName = 'PDF Upload';
              if (method == 'image') featureName = 'Image Scanning';
              if (method == 'slides') featureName = 'Slides Upload';

              if (!_checkProAccess(featureName)) return;
            }
            setState(() => _selectedImportMethod = method);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
                    size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                if (isDisabled) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveImportSection(ThemeData theme) {
    // Show Quick Topic section if topic controller has text or no import method selected
    if (_topicController.text.trim().isNotEmpty ||
        _selectedImportMethod.isEmpty) {
      return _buildLearnTopicSection(theme);
    }

    switch (_selectedImportMethod) {
      case 'text':
        return _buildPasteTextSection(theme);
      case 'link':
        return _buildImportWebpageSection(theme);
      case 'pdf':
        return _buildUploadPdfSection(theme);
      case 'image':
        return _buildScanImageSection(theme);
      case 'slides':
        return _buildUploadSlidesSection(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================
  // LEARN TOPIC SECTION
  // ===========================================================

  Widget _buildLearnTopicSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you want to learn today?',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Topic Input
          IgnorePointer(
            ignoring: _isProcessing || _isLoading,
            child: Opacity(
              opacity: (_isProcessing || _isLoading) ? 0.6 : 1.0,
              child: TextField(
                controller: _topicController,
                style: GoogleFonts.outfit(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g., "History of Rome" or "Python Basics"',
                  hintStyle: GoogleFonts.outfit(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(Icons.auto_awesome,
                      color: colorScheme.primary, size: 20),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Depth Selector
          Text(
            'DIFFICULTY SCALE',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            ignoring: _isProcessing || _isLoading,
            child: Opacity(
              opacity: (_isProcessing || _isLoading) ? 0.6 : 1.0,
              child: Row(
                children: [
                  _buildDepthChip('Easy', 'beginner', theme),
                  const SizedBox(width: 8),
                  _buildDepthChip('Normal', 'intermediate', theme),
                  const SizedBox(width: 8),
                  _buildDepthChip('Expert', 'advanced', theme),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Card Count Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STUDY CARDS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_topicCardCount.toInt()}',
                  style: GoogleFonts.outfit(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          IgnorePointer(
            ignoring: _isProcessing || _isLoading,
            child: Opacity(
              opacity: (_isProcessing || _isLoading) ? 0.6 : 1.0,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: colorScheme.primary,
                  inactiveTrackColor:
                      colorScheme.primary.withValues(alpha: 0.1),
                  thumbColor: colorScheme.primary,
                  overlayColor: colorScheme.primary.withValues(alpha: 0.1),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: _topicCardCount,
                  min: 5,
                  max: 30,
                  divisions: 5,
                  onChanged: (_isProcessing || _isLoading)
                      ? null
                      : (value) {
                          final user =
                              Provider.of<UserModel?>(context, listen: false);
                          if (value > 10 && (user == null || !user.isPro)) {
                            showDialog(
                              context: context,
                              builder: (_) => const UpgradeDialog(
                                  featureName: 'High Card Volume'),
                            );
                            // Snap back to limit
                            setState(() => _topicCardCount = 10);
                            return;
                          }
                          setState(() => _topicCardCount = value);
                        },
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          // AI Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: Colors.amber[800]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI generated content may contain inaccuracies. Verify with sources.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.amber[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepthChip(String label, String value, ThemeData theme) {
    final isSelected = _topicDepth == value;
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        if (value == 'advanced') {
          if (!_checkProAccess('Expert Deep Learning')) return;
        }
        setState(() => _topicDepth = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _processTopicGeneration(UserModel user) async {
    if (_isCancelled) return;

    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() => _errorMessage = 'Please enter a topic to learn about.');
      return;
    }

    final aiService = Provider.of<EnhancedAIService>(context, listen: false);
    final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
    final navigator = Navigator.of(context);

    // Show progress dialog with cancellation support
    final progressNotifier =
        ValueNotifier<String>('Preparing to generate study materials...');

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return WillPopScope(
            onWillPop: () async {
              _isCancelled = true;
              return true;
            },
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Learning about "$topic"',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: progressNotifier,
                    builder: (context, value, _) {
                      return Text(
                        value,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );
    }

    try {
      final folderId = await aiService.generateFromTopic(
        topic: topic,
        userId: user.uid,
        localDb: localDb,
        depth: _topicDepth,
        cardCount: _topicCardCount.toInt(),
        onProgress: (message) {
          if (!_isCancelled && mounted) {
            progressNotifier.value = message;
          }
        },
      );

      if (!_isCancelled && mounted) {
        try {
          navigator.pop(); // Close progress dialog
        } catch (_) {}

        // Navigate to results
        context.push('/results-view/$folderId');

        // Clear inputs
        _resetInputs();
      }
    } on Exception catch (e) {
      if (!_isCancelled && mounted) {
        try {
          navigator.pop(); // Close progress dialog
        } catch (_) {}

        setState(() {
          _errorMessage = _getUserFriendlyError(e);
        });
      }
    }
  }

  Widget _buildPasteTextSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          IgnorePointer(
            ignoring: _isProcessing || _isLoading,
            child: Opacity(
              opacity: (_isProcessing || _isLoading) ? 0.6 : 1.0,
              child: TextField(
                controller: _textController,
                maxLines: 8,
                onTap: _activateTextField,
                style: GoogleFonts.outfit(
                    color: theme.colorScheme.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type or paste your notes here...',
                  hintStyle: GoogleFonts.outfit(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(24),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: IgnorePointer(
              ignoring: _isProcessing || _isLoading,
              child: Opacity(
                opacity: (_isProcessing || _isLoading) ? 0.6 : 1.0,
                child: TextButton.icon(
                  onPressed: (_isProcessing || _isLoading)
                      ? null
                      : () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (data != null) {
                            _activateTextField();
                            _textController.text = data.text ?? '';
                            setState(() {});
                          }
                        },
                  icon: Icon(Icons.paste_rounded,
                      size: 18, color: theme.colorScheme.onPrimary),
                  label: Text('Paste',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
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
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _linkController.text.isEmpty
                  ? colorScheme.outline.withValues(alpha: 0.1)
                  : isValid
                      ? Colors.green.withValues(alpha: 0.5)
                      : Colors.red.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _linkController.text.isEmpty
                      ? colorScheme.surfaceContainerHighest
                      : isValid
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.link_rounded,
                  color: _linkController.text.isEmpty
                      ? colorScheme.primary
                      : isValid
                          ? Colors.green
                          : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: IgnorePointer(
                  ignoring: _isProcessing || _isLoading,
                  child: Opacity(
                    opacity: (_isProcessing || _isLoading) ? 0.6 : 1.0,
                    child: TextField(
                      controller: _linkController,
                      onTap: _activateLinkField,
                      onChanged: (value) =>
                          setState(() {}), // Trigger rebuild for validation
                      style: GoogleFonts.outfit(
                        color: colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Paste any URL here...',
                        hintStyle: GoogleFonts.outfit(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.tips_and_updates_rounded,
                  size: 14, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI-powered extraction: YouTube (multimodal), research articles, public PDFs, and educational links.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadPdfSection(ThemeData theme) {
    final bool isSelected = _pdfBytes != null;
    final colorScheme = theme.colorScheme;
    final isDisabled = _isLoading || _isProcessing;

    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: GestureDetector(
          onTap: isDisabled ? null : _pickPdf,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
                style: BorderStyle.solid,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: isDisabled
                      ? SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary),
                          ),
                        )
                      : Icon(
                          isSelected
                              ? Icons.picture_as_pdf_rounded
                              : Icons.cloud_upload_outlined,
                          color: colorScheme.primary,
                          size: 32,
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  isSelected
                      ? (_pdfName ?? 'PDF Selected')
                      : 'Upload PDF Document',
                  style: GoogleFonts.outfit(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isDisabled
                      ? 'Processing...'
                      : isSelected
                          ? 'Tap to change file'
                          : 'Maximum size 15MB',
                  style: GoogleFonts.outfit(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSlidesSection(ThemeData theme) {
    final bool isSelected = _pdfBytes != null;
    final colorScheme = theme.colorScheme;
    final isDisabled = _isLoading || _isProcessing;

    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: GestureDetector(
          onTap: isDisabled ? null : _pickPdf, // Reuse the same pick method
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
                style: BorderStyle.solid,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: isDisabled
                      ? SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary),
                          ),
                        )
                      : Icon(
                          isSelected
                              ? Icons.slideshow_rounded
                              : Icons.upload_file_rounded,
                          color: colorScheme.primary,
                          size: 32,
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  isSelected
                      ? (_pdfName ?? 'Slides Selected')
                      : 'Upload Slides',
                  style: GoogleFonts.outfit(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isDisabled
                      ? 'Processing...'
                      : isSelected
                          ? 'Tap to change file'
                          : 'Maximum size 15MB',
                  style: GoogleFonts.outfit(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanImageSection(ThemeData theme) {
    final bool isCameraSelected =
        _imageBytes != null && _imageName?.contains('camera') == true;
    final bool isGallerySelected =
        _imageBytes != null && _imageName?.contains('gallery') == true;
    final isDisabled = _isLoading || _isProcessing;

    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: Row(
          children: [
            Expanded(
                child: _buildScanButton(
                    'Camera',
                    Icons.camera_alt_rounded,
                    () => _pickImage(ImageSource.camera),
                    isCameraSelected,
                    theme,
                    isDisabled)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildScanButton(
                    'Gallery',
                    Icons.photo_library_rounded,
                    () => _pickImage(ImageSource.gallery),
                    isGallerySelected,
                    theme,
                    isDisabled)),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton(String label, IconData icon, VoidCallback onPressed,
      bool isSelected, ThemeData theme, bool isDisabled) {
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.1)
                    : colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: isDisabled
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    )
                  : Icon(icon, color: colorScheme.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              isDisabled ? 'Processing...' : label,
              style: GoogleFonts.outfit(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessButton(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isMethodSelected = _topicController.text.trim().isNotEmpty ||
        _selectedImportMethod.isNotEmpty;
    final isEnabled = isMethodSelected && !_isProcessing && !_isLoading;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: isMethodSelected ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isMethodSelected ? 1 : 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: IgnorePointer(
            ignoring: !isEnabled,
            child: Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                gradient: isEnabled
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          colorScheme.surfaceContainerHighest,
                          colorScheme.surfaceContainer
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isEnabled ? _processAndNavigate : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isProcessing || _isLoading) ...[
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ] else ...[
                          const Icon(Icons.auto_awesome_rounded,
                              color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          _isProcessing || _isLoading
                              ? (_currentOperation.isEmpty
                                  ? 'PROCESSING...'
                                  : _currentOperation.toUpperCase())
                              : 'GENERATE NOW',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
