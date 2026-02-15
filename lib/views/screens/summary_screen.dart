import 'dart:developer' as developer;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/user_model.dart';
import '../../services/local_database_service.dart';
import '../../services/enhanced_ai_service.dart';
import '../../services/usage_service.dart';
import 'package:collection/collection.dart';
import '../widgets/upgrade_dialog.dart';
import '../../models/public_deck.dart';
import '../../services/firestore_service.dart';
import '../../services/export_service.dart';

enum ScreenState { initial, loading, error, success }

class SummaryScreen extends StatefulWidget {
  final LocalSummary? summary;

  const SummaryScreen({super.key, this.summary});

  @override
  SummaryScreenState createState() => SummaryScreenState();
}

class SummaryScreenState extends State<SummaryScreen> {
  final TextEditingController _textController = TextEditingController();
  String? _pdfFileName;
  ScreenState _state = ScreenState.initial;
  String _summaryContent = '';
  String _summaryTitle = '';
  List<String> _summaryTags = [];
  String _errorMessage = '';
  String _loadingMessage = 'Generating Summary...';
  bool _isGeneratingQuiz = false;

  late final EnhancedAIService _aiService;
  late final LocalDatabaseService _localDbService;

  @override
  void initState() {
    super.initState();
    _aiService = EnhancedAIService(
        iapService: Provider.of<IAPService>(context, listen: false));
    _localDbService = LocalDatabaseService();
    _localDbService.init();
    if (widget.summary != null) {
      _summaryContent = widget.summary!.content;
      _summaryTitle = widget.summary!.title;
      _summaryTags = widget.summary!.tags;
      _state = ScreenState.success;
    }
  }

  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _pdfFileName = result.files.single.name;
        });
      }
    } catch (e, s) {
      developer.log('Error picking or reading PDF',
          name: 'summary.screen', error: e, stackTrace: s);
      setState(() {
        _state = ScreenState.error;
        _errorMessage = "Error picking or reading PDF: $e";
      });
    }
  }

  void _generateSummary() async {
    final userModel = Provider.of<UserModel?>(context, listen: false);
    final usageService = Provider.of<UsageService?>(context, listen: false);
    if (userModel == null || usageService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('User not available. Please log in again.')));
      return;
    }

    if (!userModel.isPro &&
        !(await usageService.canPerformAction(userModel.uid, 'summaries'))) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (context) =>
                const UpgradeDialog(featureName: 'summaries'));
      }
      return;
    }

    setState(() {
      _state = ScreenState.loading;
      _loadingMessage = 'Generating summary...';
    });

    try {
      final folderId = await _aiService.generateAndStoreOutputs(
        text: _textController.text,
        title: _summaryTitle.isNotEmpty ? _summaryTitle : 'Summary',
        requestedOutputs: ['summary'],
        userId: userModel.uid,
        localDb: _localDbService,
        onProgress: (message) {
          setState(() {
            _loadingMessage = message;
          });
        },
      );

      final content = await _localDbService.getFolderContents(folderId);
      final summaryId =
          content.firstWhere((c) => c.contentType == 'summary').contentId;
      final summary = await _localDbService.getSummary(summaryId);

      if (summary != null) {
        if (!userModel.isPro) await usageService.recordAction(userModel.uid, 'summaries');
        setState(() {
          _summaryTitle = summary.title;
          _summaryContent = summary.content;
          _summaryTags = summary.tags;
          _state = ScreenState.success;
        });
      } else {
        throw Exception('Failed to retrieve the generated summary.');
      }
    } catch (e, s) {
      developer.log('An unexpected error occurred during summary generation',
          name: 'summary.screen', error: e, stackTrace: s);
      setState(() {
        _state = ScreenState.error;
        _errorMessage = "An unexpected error occurred. Please try again.";
      });
    }
  }

  void _retry() => setState(() {
        _state = ScreenState.initial;
        _summaryContent = _summaryTitle = _errorMessage = '';
        _summaryTags = [];
        _textController.clear();
        _pdfFileName = null;
      });

  void _copySummary() {
    Clipboard.setData(ClipboardData(text: _summaryContent));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary content copied to clipboard!')));
  }

  void _saveToLibrary() async {
    final user = context.read<UserModel?>();
    if (user == null) return;

    try {
      final summaryToSave = LocalSummary(
        id: const Uuid().v4(),
        userId: user.uid,
        title: _summaryTitle,
        content: _summaryContent,
        tags: _summaryTags,
        timestamp: DateTime.now(),
        isSynced: false,
      );
      await _localDbService.saveSummary(summaryToSave);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Summary saved to library!')));
    } catch (e, s) {
      developer.log('Error saving summary',
          name: 'summary.screen', error: e, stackTrace: s);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error saving summary.')));
    }
  }

  Future<void> _publishDeck() async {
    final user = context.read<UserModel?>();
    if (user == null || user.role != UserRole.creator) return;

    setState(() => _loadingMessage = 'Publishing Deck...');

    final quizzes = await _localDbService.getAllQuizzes(user.uid);
    final relatedQuiz =
        quizzes.where((q) => q.title == _summaryTitle).firstOrNull;

    final flashcards = await _localDbService.getAllFlashcardSets(user.uid);
    final relatedFlashcards =
        flashcards.where((fs) => fs.title == _summaryTitle).firstOrNull;

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Deck'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: $_summaryTitle'),
            const SizedBox(height: 8),
            const Text('Includes:'),
            Text('• Summary (Current)'),
            Text('• Quiz: ${relatedQuiz != null ? "Found" : "Not Found"}'),
            Text(
                '• Flashcards: ${relatedFlashcards != null ? "Found" : "Not Found"}'),
            const SizedBox(height: 16),
            const Text('This will make the deck public and shareable.',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publish')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final summaryData = {
        'title': _summaryTitle,
        'content': _summaryContent,
        'tags': _summaryTags,
      };

      Map<String, dynamic> quizData = {};
      if (relatedQuiz != null) {
        quizData = {
          'title': relatedQuiz.title,
          'questions': relatedQuiz.questions
              .map((q) => {
                    'question': q.question,
                    'options': q.options,
                    'correctAnswer': q.correctAnswer,
                  })
              .toList(),
        };
      }

      Map<String, dynamic> flashcardData = {};
      if (relatedFlashcards != null) {
        flashcardData = {
          'title': relatedFlashcards.title,
          'flashcards': relatedFlashcards.flashcards
              .map((f) => {
                    'question': f.question,
                    'answer': f.answer,
                  })
              .toList(),
        };
      }

      final shareCode = const Uuid().v4().substring(0, 6).toUpperCase();

      final publicDeck = PublicDeck(
        id: '',
        creatorId: user.uid,
        creatorName: user.displayName,
        title: _summaryTitle,
        description: 'Created by ${user.displayName}',
        shareCode: shareCode,
        summaryData: summaryData,
        quizData: quizData,
        flashcardData: flashcardData,
        publishedAt: DateTime.now(),
      );

      final firestoreService = FirestoreService();
      final deckId = await firestoreService.publishDeck(publicDeck);

      if (!mounted) return;

      final shareUrl = 'https://sumquiz.app/deck?id=$deckId';

      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Published Successfully!'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 48),
                    const SizedBox(height: 16),
                    SelectableText(shareUrl,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Share this link with your students.'),
                    const SizedBox(height: 16),
                    Text('Or share this Code',
                        style: Theme.of(context).textTheme.titleMedium),
                    SelectableText(shareCode,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text: 'Code: $shareCode\nLink: $shareUrl'));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Details Copied!')));
                      },
                      child: const Text('Copy All')),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close')),
                ],
              ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error publishing: $e')));
      }
    }
  }

  Future<void> _generateQuiz() async {
    setState(() => _isGeneratingQuiz = true);
    try {
      final user = context.read<UserModel?>();
      if (user == null || _summaryContent.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No summary content available to generate quiz.')));
        }
        return;
      }

      if (!mounted) return;
      
      // Navigate to quiz creation with summary content
      context.push('/create', extra: {
        'initialText': _summaryContent,
        'initialTitle': _summaryTitle,
        'mode': 'quiz'
      });
    } catch (e, s) {
      developer.log('Error navigating to quiz generation',
          name: 'summary.screen', error: e, stackTrace: s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start quiz generation: $e')));
    } finally {
      if (mounted) setState(() => _isGeneratingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.summary == null ? 'Generate Summary' : 'Summary',
            style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: BackButton(color: theme.colorScheme.onSurface),
        actions: [
          Consumer<UserModel?>(
            builder: (context, user, _) {
              if (user != null &&
                  user.role == UserRole.creator &&
                  _state == ScreenState.success) {
                return IconButton(
                  icon: const Icon(Icons.public),
                  tooltip: 'Publish Deck',
                  onPressed: _publishDeck,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_state) {
      case ScreenState.loading:
        return _buildLoadingState(theme);
      case ScreenState.error:
        return _buildErrorState(theme);
      case ScreenState.success:
        return _buildSuccessState(theme);
      default:
        return _buildInitialState(theme);
    }
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(_loadingMessage,
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7))),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildInitialState(ThemeData theme) {
    final canGenerate = _textController.text.isNotEmpty || _pdfFileName != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create Summary',
                style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface),
              ).animate().fadeIn().slideY(begin: -0.2),
              const SizedBox(height: 12),
              Text(
                'Paste your content or upload a PDF to generate a comprehensive summary',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2),
              const SizedBox(height: 48),
              TextField(
                controller: _textController,
                maxLines: 20,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                decoration: InputDecoration(
                  hintText: 'Paste your text here...',
                  hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.3)),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: theme.colorScheme.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(24),
                ),
                onChanged: (text) => setState(() {}),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.upload_file_rounded,
                        color: _pdfFileName != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      label: Text(
                        _pdfFileName ?? 'Upload PDF',
                        style: TextStyle(
                            color: _pdfFileName != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        side: BorderSide(
                            color: _pdfFileName != null
                                ? theme.colorScheme.primary
                                : theme.dividerColor,
                            width: _pdfFileName != null ? 2 : 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _pickPdf,
                    ),
                  ),
                  if (_pdfFileName != null) ...[
                    const SizedBox(width: 12),
                    IconButton(
                        onPressed: () => setState(() => _pdfFileName = null),
                        icon: Icon(Icons.close_rounded,
                            color: theme.colorScheme.error))
                  ]
                ],
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: canGenerate ? _generateSummary : null,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Generate Summary',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: theme.disabledColor,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).scale(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: theme.colorScheme.error, size: 64),
            const SizedBox(height: 24),
            Text('Something went wrong',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(_errorMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7))),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(),
    );
  }

  Widget _buildSuccessState(ThemeData theme) {
    if (_summaryTitle.isEmpty && _summaryContent.isEmpty) {
      return Center(
          child: Text('No summary available',
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6))));
    }

    final isViewingSaved = widget.summary != null;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  _summaryTitle,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ).animate().fadeIn().slideY(begin: -0.2),

                const SizedBox(height: 24),

                // Tags
                if (_summaryTags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _summaryTags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn(delay: 100.ms),

                if (_summaryTags.isNotEmpty) const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copySummary,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: theme.dividerColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (!isViewingSaved) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saveToLibrary,
                          icon:
                              const Icon(Icons.bookmark_add_rounded, size: 18),
                          label: const Text('Save'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: theme.dividerColor),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingQuiz ? null : _generateQuiz,
                        icon: _isGeneratingQuiz
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.quiz_rounded, size: 18),
                        label: const Text('Generate Quiz'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final user = context.read<UserModel?>();
                          if (user != null && !user.isPro) {
                            showDialog(
                              context: context,
                              builder: (context) => const UpgradeDialog(
                                  featureName: 'PDF Export'),
                            );
                            return;
                          }

                          final summaryToExport = LocalSummary(
                            id: widget.summary?.id ?? 'temp',
                            userId: user?.uid ?? '',
                            title: _summaryTitle,
                            content: _summaryContent,
                            tags: _summaryTags,
                            timestamp: DateTime.now(),
                            isSynced: false,
                          );

                          ExportService()
                              .exportPdf(context, summary: summaryToExport);
                        },
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Export'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: theme.dividerColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 32),

                Divider(color: theme.dividerColor),

                const SizedBox(height: 32),

                // Summary Content - Markdown Rendering
                MarkdownBody(
                  data: _summaryContent,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.8,
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    listBullet: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 48),

                // Publish Button for Creators
                Consumer<UserModel?>(builder: (context, user, _) {
                  if (user != null && user.role == UserRole.creator) {
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _publishDeck,
                        icon: const Icon(Icons.public_rounded),
                        label: const Text('Publish as Public Deck'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.colorScheme.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms);
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
