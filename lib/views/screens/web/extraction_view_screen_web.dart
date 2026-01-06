import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:sumquiz/services/auth_service.dart';

class ExtractionViewScreenWeb extends StatefulWidget {
  final String? initialText;

  const ExtractionViewScreenWeb({super.key, this.initialText});

  @override
  State<ExtractionViewScreenWeb> createState() =>
      _ExtractionViewScreenWebState();
}

enum OutputType { summary, quiz, flashcards }

class _ExtractionViewScreenWebState extends State<ExtractionViewScreenWeb> {
  late TextEditingController _textController;
  final TextEditingController _titleController =
      TextEditingController(text: 'Untitled Creation');
  final Set<OutputType> _selectedOutputs = {OutputType.summary};
  bool _isLoading = false;
  String _loadingMessage = 'Generating...';

  static const int minTextLength = 10;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _toggleOutput(OutputType type) {
    if (type == OutputType.flashcards) {
      final user = context.read<UserModel?>();
      if (user != null && !user.isPro) {
        showDialog(
          context: context,
          builder: (_) =>
              const UpgradeDialog(featureName: 'Interactive Flashcards'),
        );
        return;
      }
    }

    setState(() {
      if (_selectedOutputs.contains(type)) {
        _selectedOutputs.remove(type);
      } else {
        _selectedOutputs.add(type);
      }
    });
  }

  Future<void> _handleGenerate() async {
    if (_textController.text.trim().length < minTextLength) {
      _showError(
          'Text is too short. Please provide at least $minTextLength characters.');
      return;
    }

    if (_selectedOutputs.isEmpty) {
      _showError('Please select at least one output type.');
      return;
    }

    final user = context.read<UserModel?>();

    // Check Limits
    if (user != null) {
      final usageService = UsageService();
      if (!await usageService.canGenerateDeck(user.uid)) {
        if (mounted) {
          showDialog(
              context: context,
              builder: (_) => const UpgradeDialog(featureName: 'Daily Limit'));
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Preparing generation...';
    });

    try {
      final aiService = context.read<EnhancedAIService>();
      final localDb = context.read<LocalDatabaseService>();

      // Fix: Get userId directly from AuthService for reliability
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User is not logged in');
      }

      final userId = currentUser.uid;
      final requestedOutputs = _selectedOutputs.map((e) => e.name).toList();

      final folderId = await aiService.generateAndStoreOutputs(
        text: _textController.text,
        title: _titleController.text.isNotEmpty
            ? _titleController.text
            : 'Untitled Creation',
        requestedOutputs: requestedOutputs,
        userId: userId,
        localDb: localDb,
        onProgress: (message) {
          if (mounted) {
            setState(() => _loadingMessage = message);
          }
        },
      );

      // Record Usage
      if (user != null) {
        await UsageService().recordDeckGeneration(user.uid);
      }

      if (mounted) context.go('/library/results-view/$folderId');
    } catch (e) {
      if (mounted) _showError('Generation failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text("Create Content",
            style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold)),
      ),
      body: Row(
        children: [
          // Left: Editor
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text("Source Text",
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      cursorColor: theme.colorScheme.primary,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(24),
                        border: InputBorder.none,
                        hintText:
                            "Review and edit your text here before generating...",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().slideX(begin: -0.05).fadeIn(),

          // Right: Configuration
          Expanded(
            flex: 1,
            child: Container(
              color: theme.cardColor,
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Configuration",
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 32),

                  // Title Input
                  Text("Title",
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      hintText: "Enter a title for this study set",
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Outputs
                  Text("Generate",
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: OutputType.values.map((type) {
                      final isSelected = _selectedOutputs.contains(type);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(type.name.toUpperCase()),
                        onSelected: (_) => _toggleOutput(type),
                        backgroundColor: theme.colorScheme.surface,
                        selectedColor:
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                        labelStyle: theme.textTheme.labelLarge?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const Spacer(),

                  // Generate Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleGenerate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        // dropdownColor: Colors.white, // REMOVED invalid parameter
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: theme.colorScheme.onPrimary,
                                        strokeWidth: 2)),
                                const SizedBox(width: 12),
                                Text(_loadingMessage),
                              ],
                            )
                          : const Text("GENERATE CONTENT",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().slideX(begin: 0.05).fadeIn(),
        ],
      ),
    );
  }
}
