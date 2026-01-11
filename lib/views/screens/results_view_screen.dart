import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/local_database_service.dart';

import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:flutter/services.dart';
import 'package:sumquiz/models/flashcard.dart';
import 'package:sumquiz/views/widgets/summary_view.dart';
import 'package:sumquiz/views/widgets/quiz_view.dart';
import 'package:sumquiz/views/widgets/flashcards_view.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:uuid/uuid.dart';

class ResultsViewScreen extends StatefulWidget {
  final String folderId;

  const ResultsViewScreen({super.key, required this.folderId});

  @override
  State<ResultsViewScreen> createState() => _ResultsViewScreenState();
}

class _ResultsViewScreenState extends State<ResultsViewScreen> {
  int _selectedTab = 0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaved = false; // Track save status

  LocalSummary? _summary;
  LocalQuiz? _quiz;
  LocalFlashcardSet? _flashcardSet;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = context.read<LocalDatabaseService>();

      // Load folder to check if it's already saved
      final folder = await db.getFolder(widget.folderId);
      if (folder != null) {
        _isSaved = folder.isSaved;
      }

      final contents = await db.getFolderContents(widget.folderId);

      for (var content in contents) {
        if (content.contentType == 'summary') {
          _summary = await db.getSummary(content.contentId);
        } else if (content.contentType == 'quiz') {
          _quiz = await db.getQuiz(content.contentId);
        } else if (content.contentType == 'flashcardSet') {
          _flashcardSet = await db.getFlashcardSet(content.contentId);
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to load results: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _publishDeck() async {
    final user = context.read<UserModel?>();
    if (user == null || user.role != UserRole.creator) return;

    if (_summary == null || _quiz == null || _flashcardSet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wait for content to finish loading.')));
      return;
    }

    try {
      final firestoreService = FirestoreService();
      final publicDeckId = const Uuid().v4();

      final publicDeck = PublicDeck(
        id: publicDeckId,
        creatorId: user.uid,
        creatorName: user.email.split('@')[0],
        title: _summary!.title,
        description: "Generated from ${_summary!.title}",
        summaryData: {
          'id': _summary!.id,
          'title': _summary!.title,
          'content': _summary!.content,
          'tags': _summary!.tags ?? [],
          'timestamp': Timestamp.fromDate(_summary!.timestamp),
        },
        quizData: {
          'id': _quiz!.id,
          'title': _quiz!.title,
          'questions': _quiz!.questions.map((q) => q.toMap()).toList(),
          'timestamp': Timestamp.fromDate(_quiz!.timestamp),
        },
        flashcardData: {
          'id': _flashcardSet!.id,
          'title': _flashcardSet!.title,
          'flashcards':
              _flashcardSet!.flashcards.map((f) => f.toMap()).toList(),
          'timestamp': Timestamp.fromDate(_flashcardSet!.timestamp),
        },
        publishedAt: DateTime.now(),
        shareCode: publicDeckId.substring(0, 6).toUpperCase(),
      );

      await firestoreService.publishDeck(publicDeck);

      if (!mounted) return;

      final shareUrl = 'https://sumquiz.app/deck?id=$publicDeckId';
      final shareCode = publicDeckId.substring(0, 6).toUpperCase();

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

  Future<void> _saveToLibrary() async {
    try {
      final db = context.read<LocalDatabaseService>();
      final folder = await db.getFolder(widget.folderId);

      if (folder != null) {
        // Mark the folder as saved
        folder.isSaved = true;
        await db.saveFolder(folder);

        if (mounted) {
          setState(() => _isSaved = true);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Content saved to your library!'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              action: SnackBarAction(
                label: 'View Library',
                textColor: Colors.white,
                onPressed: () => context.go('/library'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          'Results',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Consumer<UserModel?>(builder: (context, user, _) {
            if (user?.role == UserRole.creator) {
              return IconButton(
                icon: Icon(Icons.public, color: theme.colorScheme.primary),
                tooltip: 'Publish Deck',
                onPressed: _publishDeck,
              );
            }
            return const SizedBox.shrink();
          }),
          // Show different icon based on save status
          IconButton(
            icon: Icon(
              _isSaved
                  ? Icons.library_add_check
                  : Icons.library_add_check_outlined,
              color: _isSaved ? Colors.green : theme.colorScheme.primary,
            ),
            tooltip: _isSaved ? 'Saved to Library' : 'Save to Library',
            onPressed: _isSaved ? null : _saveToLibrary,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated Background
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
                                const Color(0xFFE0F7FA),
                                Color.lerp(const Color(0xFFE0F7FA),
                                    const Color(0xFFB2EBF2), value)!,
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
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: theme.colorScheme.primary))
                : _errorMessage != null
                    ? Center(
                        child: Text(_errorMessage!,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: theme.colorScheme.error)))
                    : Column(
                        children: [
                          _buildOutputSelector(theme)
                              .animate()
                              .fadeIn()
                              .slideY(begin: -0.2),
                          Expanded(
                              child: _buildSelectedTabView(theme)
                                  .animate()
                                  .fadeIn(delay: 200.ms)),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSelector(ThemeData theme) {
    const tabs = ['Summary', 'Quizzes', 'Flashcards'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 48,
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: 200.ms,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    tabs[index],
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedTabView(ThemeData theme) {
    switch (_selectedTab) {
      case 0:
        return _buildSummaryTab(theme);
      case 1:
        return _buildQuizzesTab(theme);
      case 2:
        return _buildFlashcardsTab(theme);
      default:
        return Container();
    }
  }

  Widget _buildSummaryTab(ThemeData theme) {
    if (_summary == null) {
      return Center(
          child:
              Text('No summary available.', style: theme.textTheme.bodyMedium));
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SummaryView(
          title: _summary!.title,
          content: _summary!.content,
          tags: _summary!.tags,
          showActions: true,
          onCopy: () {
            Clipboard.setData(ClipboardData(text: _summary!.content));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Summary copied to clipboard')),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuizzesTab(ThemeData theme) {
    if (_quiz == null) {
      return Center(
          child: Text('No quiz available.', style: theme.textTheme.bodyMedium));
    }

    return QuizView(
      title: _quiz!.title,
      questions: _quiz!.questions,
      onAnswer: (isCorrect) {},
      onFinish: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz practice finished!')),
        );
      },
    );
  }

  Widget _buildFlashcardsTab(ThemeData theme) {
    if (_flashcardSet == null || _flashcardSet!.flashcards.isEmpty) {
      return Center(
          child: Text('No flashcards available.',
              style: theme.textTheme.bodyMedium));
    }

    final flashcards = _flashcardSet!.flashcards
        .map((f) => Flashcard(
              id: f.id,
              question: f.question,
              answer: f.answer,
            ))
        .toList();

    return FlashcardsView(
      title: _flashcardSet!.title,
      flashcards: flashcards,
      onReview: (index, knewIt) {},
      onFinish: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flashcard review finished!')),
        );
      },
    );
  }
}
