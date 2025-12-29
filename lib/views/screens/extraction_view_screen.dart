import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';

class ExtractionViewScreen extends StatefulWidget {
  final String? initialText;

  const ExtractionViewScreen({super.key, this.initialText});

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
  final TextEditingController _titleController = TextEditingController(text: 'Untitled Creation');
  final Set<OutputType> _selectedOutputs = {}; // Default to none, allow multi-select
  bool _isLoading = false;
  String _loadingMessage = 'Generating...';
  bool _isEditingTitle = false;

  // Add a minimum character count validation
  static const int minTextLength = 50;

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
      _showError('Please select at least one output type to generate (Summary, Quiz, or Flashcards).');
      return;
    }

    final user = context.read<UserModel?>();
    final usageService = context.read<UsageService?>();

    // Check usage limits for free users
    if (user != null && !user.isPro && usageService != null) {
      for (var output in _selectedOutputs) {
        if (!await usageService.canPerformAction(output.name)) {
          if (mounted) _showUpgradeDialog(output.name);
          return; // Stop the process if any limit is exceeded
        }
      }
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Preparing generation...';
    });

    try {
      final aiService = context.read<EnhancedAIService>();
      final localDb = context.read<LocalDatabaseService>();
      final userId = user?.uid ?? 'unknown_user';

      final requestedOutputs = _selectedOutputs.map((e) => e.name).toList();

      final folderId = await aiService.generateAndStoreOutputs(
        text: _textController.text,
        title: _titleController.text.isNotEmpty ? _titleController.text : 'Untitled Creation',
        requestedOutputs: requestedOutputs,
        userId: userId,
        localDb: localDb,
        onProgress: (message) => setState(() => _loadingMessage = message),
      );

      // Record usage for free users after successful generation
      if (user != null && !user.isPro && usageService != null) {
        for (var output in _selectedOutputs) {
          await usageService.recordAction(output.name);
        }
      }

      if (mounted) {
        // Navigate to the results screen, which shows what was just created
        context.go('/results-view/$folderId');
      }
    } on EnhancedAIServiceException catch (e) {
      _showError('AI Processing Error: Failed to create content. The AI may have returned an invalid format. Please try again. Error: ${e.message}');
    } catch (e) {
      _showError('Failed to generate content after several attempts. The AI model may be temporarily unavailable.');
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
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.iconTheme.color),
          onPressed: () => context.pop(),
        ),
        title: _isEditingTitle ? _buildTitleEditor() : Text(_titleController.text, style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Edit Title',
            icon: Icon(_isEditingTitle ? Icons.check : Icons.edit_outlined, size: 22),
            onPressed: () => setState(() => _isEditingTitle = !_isEditingTitle),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Space for FAB
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. Choose what to generate:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildOutputSelector(),
                const SizedBox(height: 24),
                 Text('2. Review your text:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 12),
                Expanded(child: _buildDocumentDisplayArea()),
              ],
            ),
          ),
           if (!_isLoading) 
             Align(
              alignment: Alignment.bottomCenter,
              child: _buildGenerateButton(),
            ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 24),
                        Text(
                          _loadingMessage,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

   Widget _buildTitleEditor() {
    return TextField(
      controller: _titleController,
      autofocus: true,
      style: Theme.of(context).textTheme.titleLarge,
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Enter a title...',
      ),
      onSubmitted: (_) => setState(() => _isEditingTitle = false),
    );
  }

  Widget _buildOutputSelector() {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      children: OutputType.values.map((type) {
        final isSelected = _selectedOutputs.contains(type);
        return FilterChip(
          label: Text(StringExtension(type.name).capitalize()),
          selected: isSelected,
          onSelected: (_) => _toggleOutput(type),
          showCheckmark: true, // Explicitly show the checkmark
          backgroundColor: theme.cardColor,
          selectedColor: theme.colorScheme.secondary,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? theme.colorScheme.onSecondary : theme.textTheme.bodyLarge?.color,
          ),
          checkmarkColor: theme.colorScheme.onSecondary,
          shape: StadiumBorder(side: BorderSide(color: isSelected ? Colors.transparent : theme.dividerColor)),
        );
      }).toList(),
    );
  }

  Widget _buildDocumentDisplayArea() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        readOnly: false, // Always editable
        controller: _textController,
        maxLines: null,
        expands: true,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration.collapsed(
          hintText: 'Your extracted or pasted text appears here. You can edit it before generating.',
          hintStyle: theme.textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _handleGenerate,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generate Selected Content'),
          style: ElevatedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSecondary,
            backgroundColor: theme.colorScheme.secondary,
            textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
        ),
      ),
    );
  }
}

// A simple extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
