import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/services/notification_integration.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/models/extraction_result.dart';

class ExtractionViewScreen extends StatefulWidget {
  final ExtractionResult? result;

  const ExtractionViewScreen({super.key, this.result});

  @override
  State<ExtractionViewScreen> createState() => _ExtractionViewScreenState();
}

enum OutputType {
  summary,
  quiz,
  flashcards,
}

class _ExtractionViewScreenState extends State<ExtractionViewScreen> {
  late TextEditingController _textController;
  late TextEditingController _titleController;
  final Set<OutputType> _selectedOutputs =
      {}; // Default to none, allow multi-select
  bool _isLoading = false;
  String _loadingMessage = 'Generating...';
  bool _isEditingTitle = false;

  // Add a minimum character count validation
  static const int minTextLength = 10;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.result?.text ?? '');
    _titleController = TextEditingController(
        text: widget.result?.suggestedTitle ?? 'Untitled Creation');
    _selectedOutputs.add(OutputType.summary); // Select Summary by default
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _toggleOutput(OutputType type) {
    // All output types now available to all users within their limits
    // The limit check happens in _handleGenerate()
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
          'The text is too short. Please provide at least $minTextLength characters to ensure high-quality content generation.');
      return;
    }

    if (_selectedOutputs.isEmpty) {
      _showError(
          'Please select at least one output type to generate (Summary, Quiz, or Flashcards).');
      return;
    }

    final user = context.read<UserModel?>();

    // Check usage limits for all users (Freemium & Pro caps)
    if (user != null) {
      final usageService = UsageService();
      if (!await usageService.canGenerateDeck(user.uid)) {
        _showUpgradeDialog('Daily Limit');
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

      // Fix: Get userId directly from AuthService to avoid 'unknown_user' if UserModel stream is lagging
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
        onProgress: (message) => setState(() => _loadingMessage = message),
      );

      // Record usage (Deck Generation)
      if (user != null) {
        await UsageService().recordDeckGeneration(user.uid);
      }

      // 🔔 Schedule notifications after content generation
      if (mounted) {
        try {
          await NotificationIntegration.onContentGenerated(
            context,
            userId,
            _titleController.text.isNotEmpty
                ? _titleController.text
                : 'Untitled Creation',
          );
        } catch (e) {
          // Don't block navigation if notification scheduling fails
          debugPrint('Failed to schedule notifications: $e');
        }
      }

      if (mounted) {
        // Navigate to the results screen, which shows what was just created
        context.go('/library/results-view/$folderId');
      }
    } on EnhancedAIServiceException catch (e) {
      _showError(
          'AI Processing Error: Failed to create content. The AI may have returned an invalid format. Please try again. Error: ${e.message}');
    } catch (e) {
      _showError(
          'Failed to generate content after several attempts. The AI model may be temporarily unavailable.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showUpgradeDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => UpgradeDialog(featureName: feature),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: _isEditingTitle
            ? _buildTitleEditor(theme)
            : Text(_titleController.text,
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
                overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Edit Title',
            icon: Icon(_isEditingTitle ? Icons.check : Icons.edit_outlined,
                color: theme.colorScheme.onSurface, size: 22),
            onPressed: () => setState(() => _isEditingTitle = !_isEditingTitle),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated Gradient Background
          Animate(
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: [
              CustomEffect(
                duration: 10.seconds,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                theme.colorScheme.surface,
                                Color.lerp(theme.colorScheme.surface,
                                    theme.colorScheme.primaryContainer, value)!,
                              ]
                            : [
                                const Color(0xFFE3F2FD), // Blue 50
                                Color.lerp(
                                    const Color(0xFFE3F2FD),
                                    const Color(0xFFBBDEFB),
                                    value)!, // Blue 100
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
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 100), // Space for FAB
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Usage Banner for free users
                  _buildUsageBanner(theme),
                  Text('1. Choose content to create:',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface))
                      .animate()
                      .fadeIn()
                      .slideX(),
                  const SizedBox(height: 12),
                  _buildOutputSelector(theme).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 24),
                  Text('2. Review your text:',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface))
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .slideX(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildDocumentDisplayArea(theme)
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .scale(begin: const Offset(0.95, 0.95)),
                  ),
                ],
              ),
            ),
          ),
          if (!_isLoading)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildGenerateButton(theme)
                  .animate()
                  .fadeIn(delay: 400.ms)
                  .slideY(begin: 0.2),
            ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withValues(alpha: 0.9),
                        border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: theme.colorScheme.primary),
                          const SizedBox(height: 24),
                          Text(
                            _loadingMessage,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: theme.colorScheme.onSurface),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _isLoading = false);
                            },
                            icon: Icon(Icons.close, color: Colors.redAccent),
                            label: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleEditor(ThemeData theme) {
    return TextField(
      controller: _titleController,
      autofocus: true,
      style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
      cursorColor: theme.colorScheme.primary,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: 'Enter a title...',
        hintStyle: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
      onSubmitted: (_) => setState(() => _isEditingTitle = false),
    );
  }

  Widget _buildOutputSelector(ThemeData theme) {
    return Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      children: OutputType.values.map((type) {
        final isSelected = _selectedOutputs.contains(type);
        return GestureDetector(
          onTap: () => _toggleOutput(type),
          child: AnimatedContainer(
            duration: 200.ms,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.2)
                  : theme.cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  StringExtension(type.name).capitalize(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                ]
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDocumentDisplayArea(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
          ),
          child: TextField(
            readOnly: false, // Always editable
            controller: _textController,
            maxLines: null,
            expands: true,
            style: theme.textTheme.bodyMedium
                ?.copyWith(height: 1.5, color: theme.colorScheme.onSurface),
            cursorColor: theme.colorScheme.primary,
            decoration: InputDecoration.collapsed(
              hintText:
                  'Your extracted or pasted text appears here. You can edit it before generating.',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ElevatedButton(
              onPressed: _handleGenerate,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.onPrimary),
                  const SizedBox(width: 12),
                  Text('Generate Content',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Usage banner showing remaining generations for free users
  Widget _buildUsageBanner(ThemeData theme) {
    final user = context.watch<UserModel?>();

    // Don't show for Pro users
    if (user == null || user.isPro) {
      return const SizedBox.shrink();
    }

    // Calculate usage
    final now = DateTime.now();
    final lastGen = user.lastDeckGenerationDate;
    final isNewDay = lastGen == null ||
        now.year != lastGen.year ||
        now.month != lastGen.month ||
        now.day != lastGen.day;

    final used = isNewDay ? 0 : user.dailyDecksGenerated;
    final limit = 2; // Free tier daily limit
    final remaining = limit - used;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: remaining > 0
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: remaining > 0
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            remaining > 0 ? Icons.info_outline : Icons.warning_amber_rounded,
            color:
                remaining > 0 ? theme.colorScheme.primary : Colors.orange[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              remaining > 0
                  ? 'Free Plan: $used/$limit today'
                  : 'Daily limit reached',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/subscription'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Upgrade',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }
}

// A simple extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
