import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/widgets/pro_gate.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/usage_service.dart';

class CreateContentScreenWeb extends StatefulWidget {
  const CreateContentScreenWeb({super.key});

  @override
  State<CreateContentScreenWeb> createState() => _CreateContentScreenWebState();
}

class _CreateContentScreenWebState extends State<CreateContentScreenWeb> {
  int _selectedInputIndex = 0;
  bool _isLoading = false;

  // Controllers
  final TextEditingController _textInputController = TextEditingController();
  final TextEditingController _urlInputController = TextEditingController();

  PlatformFile? _selectedFile;

  final List<Map<String, dynamic>> _inputMethods = [
    {
      'icon': Icons.description_outlined,
      'label': 'Text',
      'description': 'Paste text directly'
    },
    {'icon': Icons.link, 'label': 'Link', 'description': 'Article or YouTube'},
    {
      'icon': Icons.upload_file,
      'label': 'PDF',
      'description': 'Upload document'
    },
    {
      'icon': Icons.image_outlined,
      'label': 'Image',
      'description': 'Photo or screenshot'
    },
  ];

  @override
  void dispose() {
    _textInputController.dispose();
    _urlInputController.dispose();
    super.dispose();
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

  Future<void> _handleFileSelection(bool isImage) async {
    if (!_checkProAccess(isImage ? 'Image Scan' : 'PDF Upload')) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: isImage ? FileType.image : FileType.custom,
        allowedExtensions: isImage ? null : ['pdf'],
        withData: true, // Important for web
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _processContent() async {
    final user = Provider.of<UserModel?>(context, listen: false);

    // Check Limits
    // If not logged in? Web create screen might allow guest? No, prompt implies user base building.
    // If user is null, we can't track.

    if (user != null) {
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
    } else {
      // Force login?
      // The original code didn't force login in _processContent explicitly but extraction might fail or be allowed?
      // Let's assume user must be logged in for tracking.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create content.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final extractionService = context.read<ContentExtractionService>();
      String extractedText = '';

      switch (_selectedInputIndex) {
        case 0: // Text
          extractedText = _textInputController.text;
          break;
        case 1: // Link
          if (!_checkProAccess('Web Link')) {
            setState(() => _isLoading = false);
            return;
          }
          extractedText = await extractionService.extractContent(
            type: 'link',
            input: _urlInputController.text,
          );
          break;
        case 2: // PDF
          // Access checked in picker
          if (_selectedFile != null && _selectedFile!.bytes != null) {
            extractedText = await extractionService.extractContent(
              type: 'pdf',
              input: _selectedFile!.bytes,
            );
          }
          break;
        case 3: // Image
          // Access checked in picker
          if (_selectedFile != null && _selectedFile!.bytes != null) {
            extractedText = await extractionService.extractContent(
              type: 'image',
              input: _selectedFile!.bytes,
            );
          }
          break;
      }

      if (extractedText.isNotEmpty) {
        // Record Usage
        await UsageService().recordDeckGeneration(user.uid);
      
        if (mounted) {
          context.go('/create/extraction-view', extra: extractedText);
        }
      } else {
        throw Exception('No content extracted');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extraction failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Create Content',
            style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A237E))),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : const Color(0xFF1A237E)),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Stack(
        children: [
          // Animated Background
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Left Side - Input Selection
                  Expanded(
                    flex: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: theme.cardColor
                                .withValues(alpha: isDark ? 0.5 : 0.7),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color:
                                    theme.dividerColor.withValues(alpha: 0.1),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Create New",
                                  style: theme.textTheme.displaySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary)),
                              const SizedBox(height: 8),
                              Text(
                                  "Import content to generate summaries and quizzes",
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.7))),
                              const SizedBox(height: 48),

                              // Input Methods Grid
                              SizedBox(
                                height: 120,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _inputMethods.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 16),
                                  itemBuilder: (context, index) {
                                    final method = _inputMethods[index];
                                    final isSelected =
                                        _selectedInputIndex == index;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedInputIndex = index;
                                          _selectedFile = null;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: 200.ms,
                                        width: 140,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : theme.cardColor
                                                    .withValues(alpha: 0.5),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: isSelected
                                                    ? Colors.transparent
                                                    : theme.dividerColor),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                        color: theme
                                                            .colorScheme.primary
                                                            .withValues(
                                                                alpha: 0.3),
                                                        blurRadius: 12,
                                                        offset:
                                                            const Offset(0, 4))
                                                  ]
                                                : []),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(method['icon'] as IconData,
                                                color: isSelected
                                                    ? theme
                                                        .colorScheme.onPrimary
                                                    : theme.colorScheme.primary,
                                                size: 28),
                                            const SizedBox(height: 8),
                                            Text(method['label'] as String,
                                                style: theme
                                                    .textTheme.labelLarge
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isSelected
                                                            ? theme.colorScheme
                                                                .onPrimary
                                                            : theme.colorScheme
                                                                .onSurface)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Divider
                              Divider(color: theme.dividerColor),
                              const SizedBox(height: 40),

                              // Input Area
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: 300.ms,
                                  child: _buildInputArea(theme),
                                ),
                              ),

                              // Action Bar
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _processContent,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor:
                                        theme.colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    elevation: 4,
                                    shadowColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.3),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              color:
                                                  theme.colorScheme.onPrimary,
                                              strokeWidth: 2))
                                      : Text("NEXT STEP",
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1,
                                                  color: theme
                                                      .colorScheme.onPrimary)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right Side - Illustration/Preview
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_selectedInputIndex >= 2)
                            Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: ProGate(
                                featureName: _inputMethods[_selectedInputIndex]
                                    ['label'] as String,
                                proContent: () => _buildSafetyInfo(theme),
                                freeContent: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: theme.cardColor.withValues(
                                              alpha: isDark ? 0.5 : 0.7),
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          border: Border.all(
                                              color: theme.dividerColor
                                                  .withValues(alpha: 0.6)),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(Icons.star_border,
                                                size: 48, color: Colors.amber),
                                            const SizedBox(height: 16),
                                            Text("Pro Feature",
                                                style: theme
                                                    .textTheme.headlineSmall
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            Text(
                                                "Upload unlimited PDFs and Images with Pro.",
                                                textAlign: TextAlign.center,
                                                style:
                                                    theme.textTheme.bodyMedium),
                                          ],
                                        )),
                                  ),
                                ),
                              ),
                            )
                          else
                            _buildSafetyInfo(theme),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    switch (_selectedInputIndex) {
      case 0:
        return TextField(
          controller: _textInputController,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
              hintText: "Paste your text here...",
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4)),
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(24)),
        );
      case 1:
        return Column(
          children: [
            TextField(
              controller: _urlInputController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.link),
                  hintText: "Paste URL (Article, YouTube, etc.)",
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(24)),
            ),
          ],
        );
      case 2:
      case 3:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  _selectedFile == null
                      ? Icons.cloud_upload_outlined
                      : Icons.check_circle_outline,
                  size: 64,
                  color: _selectedFile == null
                      ? theme.disabledColor
                      : Colors.green),
              const SizedBox(height: 16),
              Text(
                _selectedFile == null
                    ? "Drag & drop or click to upload"
                    : _selectedFile!.name,
                style: theme.textTheme.titleMedium?.copyWith(
                    color: _selectedFile == null
                        ? theme.disabledColor
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => _handleFileSelection(_selectedInputIndex == 3),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    side: BorderSide(color: theme.dividerColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: Text(
                    _selectedFile == null ? "Select File" : "Change File",
                    style: TextStyle(color: theme.colorScheme.primary)),
              )
            ],
          ),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildSafetyInfo(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: isDark ? 0.5 : 0.7),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
              )
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome,
                    size: 48, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text("Smart Generation",
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary)),
              const SizedBox(height: 12),
              Text(
                "Our AI automatically analyzes your content to create the best study materials. Please verify the generated content for accuracy.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
