import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/local_quiz_question.dart';

class QuizView extends StatefulWidget {
  final String title;
  final List<LocalQuizQuestion> questions;
  final VoidCallback? onFinish;
  final bool showSaveButton;
  final VoidCallback? onSaveProgress;
  final Function(bool isCorrect)? onAnswer;

  const QuizView({
    super.key,
    required this.title,
    required this.questions,
    this.onFinish,
    this.showSaveButton = false,
    this.onSaveProgress,
    this.onAnswer,
  });

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _answerWasSelected = false;

  void _onAnswerSelected(int index) {
    if (_answerWasSelected) return;

    setState(() {
      _selectedAnswerIndex = index;
      _answerWasSelected = true;
    });

    if (widget.onAnswer != null) {
      final question = widget.questions[_currentQuestionIndex];
      final isCorrect = question.options[index] == question.correctAnswer;
      widget.onAnswer!(isCorrect);
    }
  }

  void _handleNextQuestion() {
    if (!_answerWasSelected) return;

    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _answerWasSelected = false;
      });
    } else {
      // Quiz Finished
      widget.onFinish?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.questions.isEmpty) {
      return Center(
          child: Text("No questions available.",
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurface)));
    }

    final question = widget.questions[_currentQuestionIndex];
    // Calculate progress
    final double progress =
        (_currentQuestionIndex + 1) / widget.questions.length;

    return Column(
      children: [
        // Top Bar with progress
        _buildTopBar(progress, theme),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Question Card
                  _buildGlassContainer(
                    theme: theme,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Question ${_currentQuestionIndex + 1}',
                          style: theme.textTheme.titleMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          question.question,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        )
                            .animate(key: ValueKey(_currentQuestionIndex))
                            .fadeIn()
                            .scale(),
                      ],
                    ),
                  ).animate().slideY(begin: -0.2).fade(),

                  const SizedBox(height: 32),

                  // Options List
                  ...List.generate(question.options.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildOptionTile(index, question, theme),
                    );
                  }).animate(interval: 100.ms).slideX(begin: 0.2).fade(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // Bottom Action Area
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _answerWasSelected ? _handleNextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor:
                    theme.disabledColor.withValues(alpha: 0.3),
              ),
              child: Text(
                _currentQuestionIndex < widget.questions.length - 1
                    ? 'Next Question'
                    : 'Finish Quiz',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(double progress, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.showSaveButton && widget.onSaveProgress != null)
                IconButton(
                  icon: Icon(Icons.enhance_photo_translate,
                      color: theme.colorScheme.primary),
                  onPressed: widget.onSaveProgress,
                  // Actually, let's stick to save_alt
                ).animate().scale(),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.disabledColor.withValues(alpha: 0.2),
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
      int index, LocalQuizQuestion question, ThemeData theme) {
    bool isSelected = _selectedAnswerIndex == index;
    bool isCorrect = question.options[index] == question.correctAnswer;

    // Determine visuals state
    Color borderColor = Colors.transparent;
    Color backgroundColor = theme.cardColor.withValues(alpha: 0.6);
    IconData icon = Icons.circle_outlined;
    Color iconColor = theme.disabledColor;

    if (_answerWasSelected) {
      if (isCorrect) {
        borderColor = Colors.green;
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        icon = Icons.check_circle_rounded;
        iconColor = Colors.green;
      } else if (isSelected) {
        borderColor = Colors.red;
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        icon = Icons.cancel_rounded;
        iconColor = Colors.red;
      } else {
        // Unselected and not correct - fade it out slightly
        backgroundColor = theme.cardColor.withValues(alpha: 0.4);
      }
    } else if (isSelected) {
      // Just selected
    }

    return GestureDetector(
      onTap: () => _onAnswerSelected(index),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _answerWasSelected && (isCorrect || isSelected)
                  ? borderColor
                  : theme.dividerColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ]),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24)
                .animate(
                    target:
                        _answerWasSelected && (isCorrect || isSelected) ? 1 : 0)
                .scale(duration: 200.ms, curve: Curves.easeOutBack),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                question.options[index],
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassContainer(
      {required Widget child,
      EdgeInsetsGeometry? padding,
      required ThemeData theme}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
