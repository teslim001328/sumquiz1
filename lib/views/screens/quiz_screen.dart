import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:uuid/uuid.dart';

import '../../models/user_model.dart';
import '../../models/local_quiz.dart';
import '../../models/local_quiz_question.dart';
import '../../services/enhanced_ai_service.dart';
import '../../services/local_database_service.dart';
import '../../services/usage_service.dart';
import '../../view_models/quiz_view_model.dart';
import '../widgets/upgrade_dialog.dart';

enum QuizState { creation, loading, inProgress, finished, error }

class QuizScreen extends StatefulWidget {
  final LocalQuiz? quiz;
  final String? initialText;
  final String? initialTitle;

  const QuizScreen({
    super.key,
    this.quiz,
    this.initialText,
    this.initialTitle,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final EnhancedAIService _aiService = EnhancedAIService();
  final LocalDatabaseService _localDbService = LocalDatabaseService();

  QuizState _state = QuizState.creation;
  String _loadingMessage = 'Generating Quiz...';
  String _errorMessage = '';

  late List<LocalQuizQuestion> _questions;
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _answerWasSelected = false;
  int _score = 0;
  String? _quizId;

  @override
  void initState() {
    super.initState();
    _localDbService.init();

    if (widget.quiz != null) {
      _questions = widget.quiz!.questions;
      _titleController.text = widget.quiz!.title;
      _quizId = widget.quiz!.id;
      _state = QuizState.inProgress;
    } else {
      _questions = [];
      _quizId = const Uuid().v4();
      _textController.text = widget.initialText ?? '';
      _titleController.text = widget.initialTitle ?? '';
      if (widget.initialText?.isNotEmpty == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _generateQuiz();
        });
      }
    }
  }

  Future<void> _generateQuiz() async {
    if (_titleController.text.isEmpty || _textController.text.isEmpty) {
      setState(() {
        _state = QuizState.error;
        _errorMessage = 'Please provide both a title and text.';
      });
      return;
    }

    final userModel = Provider.of<UserModel?>(context, listen: false);
    final usageService = Provider.of<UsageService?>(context, listen: false);
    if (userModel == null || usageService == null) return;

    if (!userModel.isPro) {
      final canGenerate = await usageService.canPerformAction('quizzes');
      if (!canGenerate) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => const UpgradeDialog(featureName: 'quizzes'),
          );
        }
        return;
      }
    }

    setState(() {
      _state = QuizState.loading;
      _loadingMessage = 'Generating quiz...';
      _resetQuizState();
    });

    try {
       final folderId = await _aiService.generateAndStoreOutputs(
        text: _textController.text,
        title: _titleController.text,
        requestedOutputs: ['quiz'],
        userId: userModel.uid,
        localDb: _localDbService,
        onProgress: (message) {
          setState(() {
            _loadingMessage = message;
          });
        },
      );

      if (!userModel.isPro) {
        await usageService.recordAction('quizzes');
      }

      final content = await _localDbService.getFolderContents(folderId);
      final quizId = content.firstWhere((c) => c.contentType == 'quiz').contentId;
      final quiz = await _localDbService.getQuiz(quizId);

      if (quiz != null && quiz.questions.isNotEmpty) {
        setState(() {
          _questions = quiz.questions;
          _quizId = quiz.id;
          _state = QuizState.inProgress;
        });
      } else {
        throw Exception('AI service returned an empty quiz.');
      }
    } catch (e) {
      setState(() {
        _state = QuizState.error;
        _errorMessage = 'Error generating quiz: $e';
      });
    } 
  }

  Future<void> _saveInProgress() async {
    if (_questions.isEmpty || _titleController.text.isEmpty || _quizId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Cannot save an empty quiz."),
        ));
      }
      return;
    }

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) return;

    final quizToSave = LocalQuiz(
      id: _quizId!,
      userId: user.uid,
      title: _titleController.text,
      questions: _questions,
      timestamp: DateTime.now(),
      scores: widget.quiz?.scores ?? [],
    );

    try {
      await _localDbService.saveQuiz(quizToSave);
      if (mounted) {
        Provider.of<QuizViewModel>(context, listen: false).refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quiz progress saved!'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving progress: $e'),
        ));
      }
    }
  }

  Future<void> _saveFinalScoreAndExit() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    final quizViewModel = Provider.of<QuizViewModel>(context, listen: false);
    if (user == null || _quizId == null) return;

    final percentageScore = _questions.isNotEmpty ? (_score / _questions.length) * 100.0 : 0.0;

    var quizToSave = await _localDbService.getQuiz(_quizId!);

    if (quizToSave != null) {
      quizToSave.scores.add(percentageScore);
    } else {
      quizToSave = LocalQuiz(
        id: _quizId!,
        userId: user.uid,
        title: _titleController.text,
        questions: _questions,
        timestamp: DateTime.now(),
        scores: [percentageScore],
      );
    }

    try {
      await _localDbService.saveQuiz(quizToSave);
      quizViewModel.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Final score saved!'),
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving final score: $e'),
        ));
      }
    }
  }

  void _onAnswerSelected(int index) {
    if (_answerWasSelected) return;

    setState(() {
      _selectedAnswerIndex = index;
      _answerWasSelected = true;
      final question = _questions[_currentQuestionIndex];
      if (question.options[index] == question.correctAnswer) {
        _score++;
      }
    });
  }

  void _handleNextQuestion() {
    if (!_answerWasSelected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an answer.')),
        );
      }
      return;
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _answerWasSelected = false;
      });
    } else {
      setState(() {
        _state = QuizState.finished;
      });
    }
  }

  void _resetQuizState() {
    setState(() {
      _state = QuizState.inProgress;
      _currentQuestionIndex = 0;
      _selectedAnswerIndex = null;
      _answerWasSelected = false;
      _score = 0;
    });
  }
  
  void _retry() {
      setState(() {
        _state = QuizState.creation;
        _errorMessage = '';
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz == null ? 'Create Quiz' : 'Take Quiz'),
          actions: [
            if (_state == QuizState.inProgress)
              IconButton(
                icon: const Icon(Icons.save_alt_outlined),
                onPressed: _saveInProgress,
                tooltip: 'Save Progress',
              )
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildContent(),
          ),
        ));
  }

   Widget _buildContent() {
    switch (_state) {
      case QuizState.loading:
        return _buildLoadingState();
      case QuizState.error:
        return _buildErrorState();
      case QuizState.inProgress:
        return _buildQuizInterface();
      case QuizState.finished:
        return _buildResultScreen();
      default:
        return _buildCreationForm();
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_loadingMessage),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text('Oops! Something went wrong.', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_errorMessage, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _retry, child: const Text('Try Again')),
        ],
      ),
    );
  }

  Widget _buildCreationForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Text('Create a New Quiz', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quiz Title', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(hintText: 'e.g., History Midterm Review', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  Text('Text to Generate From', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    maxLines: 8,
                    decoration: const InputDecoration(hintText: 'Paste your notes or article here.',  border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generateQuiz,
                icon: const Icon(Icons.psychology_alt_outlined),
                label: const Text('Generate Quiz'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizInterface() {
    final question = _questions[_currentQuestionIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Text(_titleController.text,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Question ${_currentQuestionIndex + 1}/${_questions.length}',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text(
            question.question,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: _answerWasSelected ? 4 : 2,
                  color: _getTileColor(index),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _selectedAnswerIndex == index ? Theme.of(context).colorScheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    title: Text(question.options[index], style: Theme.of(context).textTheme.bodyLarge),
                    leading: _getTileIcon(index),
                    onTap: () => _onAnswerSelected(index),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _answerWasSelected ? _handleNextQuestion : null,
              child: Text(
                _currentQuestionIndex < _questions.length - 1 ? 'Next Question' : 'Finish Quiz',
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Color? _getTileColor(int index) {
    if (!_answerWasSelected) return Theme.of(context).cardColor;
    final question = _questions[_currentQuestionIndex];
    if (question.options[index] == question.correctAnswer) return Colors.green.shade50;
    if (index == _selectedAnswerIndex) return Colors.red.shade50;
    return Theme.of(context).cardColor;
  }

  Widget _getTileIcon(int index) {
    if (!_answerWasSelected) return Icon(Icons.circle_outlined, color: Theme.of(context).disabledColor);
    final question = _questions[_currentQuestionIndex];
    if (question.options[index] == question.correctAnswer) return const Icon(Icons.check_circle, color: Colors.green);
    if (index == _selectedAnswerIndex) return const Icon(Icons.cancel, color: Colors.red);
    return Icon(Icons.circle_outlined, color: Theme.of(context).disabledColor);
  }

  Widget _buildResultScreen() {
    final percentage = _questions.isNotEmpty ? (_score / _questions.length) * 100 : 0;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Quiz Results', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: theme.textTheme.displayLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text('Your Score: $_score out of ${_questions.length}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveFinalScoreAndExit,
                child: const Text('Save & Exit'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetQuizState,
                child: const Text('Retry Quiz'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
