import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/models/flashcard.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/views/widgets/flashcards_view.dart';
import 'package:sumquiz/views/widgets/quiz_view.dart';
import 'package:sumquiz/views/widgets/summary_view.dart';

class ResultsViewScreenWeb extends StatefulWidget {
  final String folderId;

  const ResultsViewScreenWeb({super.key, required this.folderId});

  @override
  State<ResultsViewScreenWeb> createState() => _ResultsViewScreenWebState();
}

class _ResultsViewScreenWebState extends State<ResultsViewScreenWeb> {
  int _selectedTab = 0;
  bool _isLoading = true;
  String? _errorMessage;

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

      // Auto-select first available tab if default (0) is empty
      if (_summary == null) {
        if (_quiz != null)
          _selectedTab = 1;
        else if (_flashcardSet != null) _selectedTab = 2;
      }
    } catch (e) {
      _errorMessage = 'Failed to load results: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _saveToLibrary() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Content saved to your library!'),
          ],
        ),
        backgroundColor: WebColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        width: 400,
      ),
    );
    context.go('/library');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          WebColors.background, // Keep simple background, content has gradient
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              WebColors.background,
              WebColors.primaryLight.withOpacity(0.3),
            ],
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: WebColors.primary))
            : _errorMessage != null
                ? Center(child: _buildErrorState())
                : Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSidebar(),
                              const SizedBox(width: 32),
                              Expanded(child: _buildContentArea()),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
        const SizedBox(height: 16),
        Text(
          _errorMessage!,
          style: TextStyle(fontSize: 18, color: WebColors.textPrimary),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => context.go('/library'),
          child: const Text('Return to Library'),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: WebColors.backgroundAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: WebColors.textPrimary),
              onPressed: () => context.pop(),
              tooltip: 'Back',
            ),
          ),
          const SizedBox(width: 24),
          Image.asset('assets/images/web/success_illustration.png',
              width: 48, height: 48),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Content Ready!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              Text(
                'Your study materials have been generated successfully',
                style: TextStyle(
                  fontSize: 14,
                  color: WebColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [WebColors.secondary, const Color(0xFF34D399)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: WebColors.secondary.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _saveToLibrary,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Save to Library',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ).animate().pulse(delay: 1.seconds, duration: 2.seconds),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTENTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: WebColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          if (_summary != null)
            _buildNavItem(
                0, 'Summary Notes', Icons.article_rounded, WebColors.primary),
          const SizedBox(height: 8),
          if (_quiz != null)
            _buildNavItem(
                1, 'Practice Quiz', Icons.quiz_rounded, WebColors.secondary),
          const SizedBox(height: 8),
          if (_flashcardSet != null)
            _buildNavItem(2, 'Flashcards Deck', Icons.style_rounded,
                WebColors.accentPink),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WebColors.primaryLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WebColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates,
                    color: WebColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Review the summary first, then test yourself with the quiz.',
                    style: TextStyle(
                        fontSize: 13,
                        color: WebColors.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, Color color) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : WebColors.textSecondary,
                fontSize: 15,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.white, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _buildSelectedTabView()
          .animate(key: ValueKey(_selectedTab))
          .fadeIn(duration: 300.ms)
          .slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _buildSelectedTabView() {
    switch (_selectedTab) {
      case 0:
        return _buildSummaryTab();
      case 1:
        return _buildQuizzesTab();
      case 2:
        return _buildFlashcardsTab();
      default:
        return _buildEmptyTab();
    }
  }

  Widget _buildEmptyTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No content available',
              style: TextStyle(color: Colors.grey[500], fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    if (_summary == null) return _buildEmptyTab();
    return SummaryView(
      title: _summary!.title,
      content: _summary!.content,
      tags: _summary!.tags,
      showActions: true,
      onCopy: () {
        Clipboard.setData(ClipboardData(text: _summary!.content));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Summary copied to clipboard'),
              behavior: SnackBarBehavior.floating,
              width: 300),
        );
      },
    );
  }

  Widget _buildQuizzesTab() {
    if (_quiz == null) return _buildEmptyTab();
    // Wrap QuizView to ensure it takes available space but doesn't overflow
    return QuizView(
      title: _quiz!.title,
      questions: _quiz!.questions,
      onAnswer: (isCorrect) {},
      onFinish: () {},
    );
  }

  Widget _buildFlashcardsTab() {
    if (_flashcardSet == null) return _buildEmptyTab();

    final flashcards = _flashcardSet!.flashcards
        .map((f) => Flashcard(
              id: f.id,
              question: f.question,
              answer: f.answer,
            ))
        .toList();

    return Center(
      child: Container(
        constraints: BoxConstraints(maxHeight: 700),
        child: FlashcardsView(
          title: _flashcardSet!.title,
          flashcards: flashcards,
          onReview: (index, knewIt) {},
          onFinish: () {},
        ),
      ),
    );
  }
}
