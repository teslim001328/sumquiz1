import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/local_flashcard.dart';
import 'package:uuid/uuid.dart';

class PublicDeckScreen extends StatefulWidget {
  final String deckId;

  const PublicDeckScreen({super.key, required this.deckId});

  @override
  State<PublicDeckScreen> createState() => _PublicDeckScreenState();
}

class _PublicDeckScreenState extends State<PublicDeckScreen> {
  bool _isLoading = true;
  PublicDeck? _deck;
  String? _error;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _fetchDeck();
  }

  Future<void> _fetchDeck() async {
    try {
      final deck = await FirestoreService().fetchPublicDeck(widget.deckId);

      if (deck == null) {
        if (mounted) {
          setState(() {
            _error = 'Deck not found or has been removed.';
            _isLoading = false;
          });
        }
        return;
      }

      // Record View for Creator Bonus
      // Fire and forget - don't block UI
      // Note: reading context in async method after await is risky for mounted check,
      // but we need the user ID.
      // Safer to rely on FirebaseAuth if we don't want to depend on Provider readiness here, matches other services
      // But let's use the Provider if mounted.
      if (mounted) {
        final user = context.read<UserModel?>();
        if (user != null) {
          FirestoreService().recordDeckView(widget.deckId, user.uid);
        }
      }

      if (mounted) {
        setState(() {
          _deck = deck;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching deck: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load deck. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importDeck() async {
    if (_deck == null) return;

    final user = context.read<UserModel?>();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to import decks.')));
      // Typically redirect to auth, but for now just show msg
      return;
    }

    setState(() => _isImporting = true);

    try {
      final localDb = LocalDatabaseService();
      // Ensure DB initialized? Usually done in main. assume yes.

      // Check if deck with same publicDeckId already exists
      final existingFlashcardSets = await localDb.getAllFlashcardSets(user.uid);
      final existingQuiz = await localDb.getAllQuizzes(user.uid);
      final existingSummary = await localDb.getAllSummaries(user.uid);

      // Check for existing items with the same publicDeckId
      final existingFlashcardSet = existingFlashcardSets.firstWhere(
        (set) => set.publicDeckId == _deck!.id,
        orElse: () => LocalFlashcardSet.empty(),
      );

      final existingQuizItem = existingQuiz.firstWhere(
        (quiz) => quiz.publicDeckId == _deck!.id,
        orElse: () => LocalQuiz.empty(),
      );

      final existingSummaryItem = existingSummary.firstWhere(
        (summary) => summary.publicDeckId == _deck!.id,
        orElse: () => LocalSummary.empty(),
      );

      // Don't import if deck already exists (any component already exists)
      if (existingFlashcardSet.id.isNotEmpty ||
          existingQuizItem.id.isNotEmpty ||
          existingSummaryItem.id.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('This deck has already been imported.')));
          setState(() => _isImporting = false);
        }
        return;
      }

      // 1. Save Summary
      if (_deck!.summaryData.isNotEmpty) {
        final summary = LocalSummary(
          id: const Uuid().v4(),
          userId: user.uid,
          title: _deck!.title,
          content: _deck!.summaryData['content'] ?? '',
          tags: List<String>.from(_deck!.summaryData['tags'] ?? []),
          timestamp: DateTime.now(),
          isSynced: false,
          isReadOnly: true,
          publicDeckId: _deck!.id,
          creatorName: _deck!.creatorName,
        );
        await localDb.saveSummary(summary);
      }

      // 2. Save Quiz
      if (_deck!.quizData.isNotEmpty) {
        final questionsList = (_deck!.quizData['questions'] as List?) ?? [];
        final questions = questionsList
            .map((q) => LocalQuizQuestion(
                  question: q['question'] ?? '',
                  options: List<String>.from(q['options'] ?? []),
                  correctAnswer: q['correctAnswer'] ?? '',
                ))
            .toList();

        final quiz = LocalQuiz(
          id: const Uuid().v4(),
          userId: user.uid,
          title: _deck!.title, // Use deck title
          questions: questions,
          timestamp: DateTime.now(),
          isSynced: false,
          isReadOnly: true,
          publicDeckId: _deck!.id,
          creatorName: _deck!.creatorName,
        );
        await localDb.saveQuiz(quiz);
      }

      // 3. Save Flashcards
      if (_deck!.flashcardData.isNotEmpty) {
        final cardsList = (_deck!.flashcardData['flashcards'] as List?) ?? [];
        final cards = cardsList
            .map((c) => LocalFlashcard(
                  question: c['question'] ?? '',
                  answer: c['answer'] ?? '',
                ))
            .toList();

        final flashcards = LocalFlashcardSet(
          id: const Uuid().v4(),
          userId: user.uid,
          title: _deck!.title,
          flashcards: cards,
          timestamp: DateTime.now(),
          isSynced: false,
          isReadOnly: true,
          publicDeckId: _deck!.id,
          creatorName: _deck!.creatorName,
        );
        await localDb.saveFlashcardSet(flashcards);
      }

      // 4. Update Metrics
      await FirestoreService()
          .incrementDeckMetric(widget.deckId, 'startedCount');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deck imported to Library!')));
        context.go('/library');
      }
    } catch (e) {
      debugPrint('Error importing deck: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error importing deck: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _deck == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error ?? 'Deck not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Public Deck')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_deck!.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Created by ${_deck!.creatorName}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              _buildContentCard(
                  Icons.summarize, 'Summary', _deck!.summaryData.isNotEmpty),
              _buildContentCard(Icons.quiz, 'Quiz', _deck!.quizData.isNotEmpty),
              _buildContentCard(
                  Icons.style, 'Flashcards', _deck!.flashcardData.isNotEmpty),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isImporting ? null : _importDeck,
                icon: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download),
                label: Text(_isImporting ? 'Importing...' : 'Add to Library'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              )
            ],
          ).animate().fadeIn().scale(),
        ),
      ),
    );
  }

  Widget _buildContentCard(IconData icon, String label, bool exists) {
    if (!exists) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(label),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}
