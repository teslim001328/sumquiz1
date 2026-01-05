import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';

import '../../models/user_model.dart';
import '../../services/usage_service.dart'; // Import UsageService

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
        _activeContentType = ContentType.pdf;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_checkProAccess('Image Scan')) return;

    final XFile? image = await _imagePicker.pickImage(source: source);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _resetInputs(except: ContentType.image);
        _imageName = image.name;
        _imageBytes = bytes;
        _activeContentType = ContentType.image;
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

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be logged in to create content.')),
      );
      return;
    }

    // Check Limits
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

    setState(() => _isLoading = true);

    try {
      final extractionService =
          Provider.of<ContentExtractionService>(context, listen: false);
      String extractedText = '';

      switch (_activeContentType!) {
        case ContentType.text:
          if (_textController.text.trim().isEmpty) {
            throw Exception('The text field is empty.');
          }
          extractedText = _textController.text;
          break;
        case ContentType.link:
          if (!_checkProAccess('Web Link')) {
            setState(() => _isLoading = false);
            return;
          }
          if (_linkController.text.trim().isEmpty) {
            throw Exception('The URL field is empty.');
          }
          extractedText = await extractionService.extractContent(
              type: 'link', input: _linkController.text);
          break;
        case ContentType.pdf:
          // Already checked in picker, but double check implies safety
          if (_pdfBytes == null) {
            throw Exception('No PDF file was selected.');
          }
          extractedText = await extractionService.extractContent(
              type: 'pdf', input: _pdfBytes);
          break;
        case ContentType.image:
          // Already checked in picker
          if (_imageBytes == null) {
            throw Exception('No image was selected.');
          }
          extractedText = await extractionService.extractContent(
              type: 'image', input: _imageBytes);
          break;
      }

      // Record Usage
      await usageService.recordDeckGeneration(user.uid);

      if (mounted) {
        context.push('/create/extraction-view', extra: extractedText);
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('New Material',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A237E),
            )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {}, // Profile action placeholder
            icon: Icon(Icons.person,
                color: isDark ? Colors.white : const Color(0xFF1A237E)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated Background (Adaptive)
          Animate(
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: [
              CustomEffect(
                duration: 6.seconds,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF0F172A),
                                Color.lerp(const Color(0xFF0F172A),
                                    const Color(0xFF1E293B), value)!
                              ]
                            : [
                                const Color(0xFFF3F4F6),
                                Color.lerp(const Color(0xFFE8EAF6),
                                    const Color(0xFFC5CAE9), value)!
                              ],
                      ),
                    ),
                    child: child,
                  );
                },
              )
            ],
            child: Container(),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'What do you want to learn today?',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A237E),
                        ),
                      ).animate().fadeIn().slideX(),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Input Text', Icons.edit, theme)
                          .animate()
                          .fadeIn(delay: 100.ms),
                      _buildPasteTextSection(theme)
                          .animate()
                          .fadeIn(delay: 150.ms),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader(
                                        'Import Webpage', Icons.link, theme)
                                    .animate()
                                    .fadeIn(delay: 200.ms),
                                _buildImportWebpageSection(theme)
                                    .animate()
                                    .fadeIn(delay: 250.ms),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Upload PDF',
                                        Icons.picture_as_pdf, theme)
                                    .animate()
                                    .fadeIn(delay: 300.ms),
                                _buildUploadPdfSection(theme)
                                    .animate()
                                    .fadeIn(delay: 350.ms),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Scan Image', Icons.fullscreen, theme)
                          .animate()
                          .fadeIn(delay: 400.ms),
                      _buildScanImageSection(theme)
                          .animate()
                          .fadeIn(delay: 450.ms),
                      const SizedBox(height: 100), // Extra space for FAB
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildGenerateButton(theme)
          .animate()
          .fadeIn(delay: 500.ms)
          .slideY(begin: 0.2),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon,
              color: theme.colorScheme.primary.withOpacity(0.7), size: 18),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(
      {required Widget child,
      required ThemeData theme,
      EdgeInsets? padding,
      bool isSelected = false,
      VoidCallback? onTap}) {
    final isDark = theme.brightness == Brightness.dark;
    final cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: 300.ms,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.cardColor.withValues(alpha: isDark ? 0.5 : 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.dividerColor.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: cardContent,
      );
    }
    return cardContent;
  }

  Widget _buildPasteTextSection(ThemeData theme) {
    return _buildGlassCard(
      theme: theme,
      isSelected: _activeContentType == ContentType.text,
      onTap: () {
        setState(() {
          _resetInputs(except: ContentType.text);
          if (_activeContentType != ContentType.text) {
            _activeContentType = ContentType.text; // Ensure active
          }
        });
      },
      child: SizedBox(
        height: 150,
        child: TextField(
          onTap: () {
            setState(() {
              _resetInputs(except: ContentType.text);
              _activeContentType = ContentType.text;
            });
          },
          controller: _textController,
          maxLines: null,
          expands: true,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Type or paste your notes here for AI summary...',
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildImportWebpageSection(ThemeData theme) {
    return _buildGlassCard(
      theme: theme,
      isSelected: _activeContentType == ContentType.link,
      onTap: () {
        setState(() {
          _resetInputs(except: ContentType.link);
          _activeContentType = ContentType.link;
        });
      },
      child: SizedBox(
        height: 100, // Fixed height to match row neighbor
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_activeContentType == ContentType.link)
              Icon(Icons.check_circle,
                  color: theme.colorScheme.primary, size: 28)
            else
              Icon(Icons.public, color: theme.disabledColor, size: 32),
            const SizedBox(height: 12),
            TextField(
              onTap: () => setState(() {
                _resetInputs(except: ContentType.link);
                _activeContentType = ContentType.link;
              }),
              controller: _linkController,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                  hintText: 'Paste URL',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadPdfSection(ThemeData theme) {
    bool isSelected = _activeContentType == ContentType.pdf && _pdfName != null;
    return _buildGlassCard(
      theme: theme,
      isSelected: isSelected,
      onTap: _pickPdf,
      child: SizedBox(
        height: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? Icons.check_circle : Icons.upload_file,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
                size: 32),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                _pdfName ?? 'Select PDF',
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withOpacity(0.6)),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanImageSection(ThemeData theme) {
    return Row(
      children: [
        Expanded(
            child: _buildScanButton('Camera', Icons.camera_alt,
                () => _pickImage(ImageSource.camera), theme)),
        const SizedBox(width: 16),
        Expanded(
            child: _buildScanButton('Gallery', Icons.photo_library,
                () => _pickImage(ImageSource.gallery), theme)),
      ],
    );
  }

  Widget _buildScanButton(
      String label, IconData icon, VoidCallback onPressed, ThemeData theme) {
    bool isSelected =
        _activeContentType == ContentType.image && _imageName != null;
    return _buildGlassCard(
      theme: theme,
      isSelected: isSelected,
      onTap: onPressed,
      child: SizedBox(
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              Icon(Icons.check_circle,
                  color: theme.colorScheme.primary, size: 24)
            else
              Icon(icon, color: theme.disabledColor, size: 24),
            const SizedBox(height: 8),
            Text(
              isSelected ? _imageName! : label,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withOpacity(0.6)),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _processAndNavigate,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 4,
            shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.onPrimary, strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Extract Content',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Icon(Icons.auto_awesome),
                  ],
                ),
        ),
      ),
    );
  }
}
