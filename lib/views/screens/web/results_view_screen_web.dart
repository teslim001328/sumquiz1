import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/models/flashcard.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import '../../widgets/summary_view.dart';
import '../../widgets/quiz_view.dart';
import '../../widgets/flashcards_view.dart';
import '../../../services/export_service.dart';
import '../../../services/local_database_service.dart';
import '../../../models/local_summary.dart';
import '../../../models/local_quiz_question.dart';
import '../../../models/local_flashcard.dart';

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
        if (_quiz != null) {
          _selectedTab = 1;
        } else if (_flashcardSet != null) {
          _selectedTab = 2;
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

  void _saveToLibrary() {
    final user = context.read<UserModel?>();
    if (user != null && !user.isPro) {
      showDialog(
        context: context,
        builder: (context) => const UpgradeDialog(featureName: 'Sharing Decks'),
      );
      return;
    }

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
      backgroundColor: WebColors.background,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: WebColors.primary))
            : _errorMessage != null
                ? Center(child: _buildErrorState())
                : Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
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
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border, width: 1.5),
        boxShadow: WebColors.cardShadow,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            onPressed: () {
              final user = context.read<UserModel?>();
              if (user != null && !user.isPro) {
                showDialog(
                  context: context,
                  builder: (context) =>
                      const UpgradeDialog(featureName: 'PDF Export'),
                );
                return;
              }

              final summary = _summary;
              if (summary == null) return;

              // Construct models same as mobile
              final localSummary = LocalSummary(
                  id: 'temp',
                  title: summary.title,
                  content: summary.content,
                  tags: [],
                  timestamp: DateTime.now(),
                  userId: user?.uid ?? '',
                  isSynced: false);

              final localQuiz = LocalQuiz(
                  id: 'temp',
                  title: summary.title,
                  questions: _quiz?.questions
                          .map((q) => LocalQuizQuestion(
                              question: q.question,
                              options: q.options,
                              correctAnswer: q.correctAnswer))
                          .toList() ??
                      [],
                  timestamp: DateTime.now(),
                  userId: user?.uid ?? '',
                  isSynced: false);

              final localFlash = LocalFlashcardSet(
                  id: 'temp',
                  title: summary.title,
                  flashcards: _flashcardSet?.flashcards
                          .map((f) => LocalFlashcard(
                              question: f.question, answer: f.answer))
                          .toList() ??
                      [],
                  timestamp: DateTime.now(),
                  userId: user?.uid ?? '',
                  isSynced: false);

              ExportService().exportPdf(context,
                  summary: localSummary,
                  quiz: localQuiz,
                  flashcardSet: localFlash);
            },
            style: IconButton.styleFrom(
              backgroundColor: WebColors.backgroundAlt,
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
            style: IconButton.styleFrom(
              backgroundColor: WebColors.backgroundAlt,
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Content Ready',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: WebColors.textPrimary,
                  ),
                ),
                Text(
                  'Your AI-generated learning materials',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: WebColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: WebColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WebColors.secondary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 14, color: WebColors.secondary),
                const SizedBox(width: 6),
                Text(
                  'AI GENERATED',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: WebColors.secondary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            decoration: BoxDecoration(
              gradient: WebColors.HeroGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: WebColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _saveToLibrary,
              icon:
                  const Icon(Icons.bookmark_added_rounded, color: Colors.white),
              label: Text(
                'Save to Library',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ).animate().shimmer(delay: 2.seconds, duration: 1.5.seconds),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border, width: 1.5),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: WebColors.backgroundAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: WebColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: WebColors.HeroGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_book, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Contents',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: WebColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_summary != null)
                    _buildNavItem(0, 'Summary Notes', Icons.article_rounded,
                        WebColors.primary),
                  const SizedBox(height: 12),
                  if (_quiz != null)
                    _buildNavItem(1, 'Practice Quiz', Icons.quiz_rounded,
                        WebColors.secondary),
                  const SizedBox(height: 12),
                  if (_flashcardSet != null)
                    _buildNavItem(2, 'Flashcards Deck', Icons.style_rounded,
                        WebColors.accentPink),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: WebColors.primaryLight.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: WebColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates_rounded,
                            color: WebColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Review the summary first, then master it with the quiz and flashcards.',
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: WebColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                height: 1.4),
                          ),
                        ),
                      ],
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

  Widget _buildNavItem(int index, String label, IconData icon, Color color) {
    final isSelected = _selectedTab == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : WebColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? color : WebColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? color : WebColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border, width: 1.5),
        boxShadow: WebColors.cardShadow,
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

    return Padding(
      padding: const EdgeInsets.all(40),
      child: SummaryView(
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
      ),
    );
  }

  Widget _buildQuizzesTab() {
    if (_quiz == null) return _buildEmptyTab();

    return Padding(
      padding: const EdgeInsets.all(40),
      child: QuizView(
        title: _quiz!.title,
        questions: _quiz!.questions,
        onAnswer: (isCorrect) {},
        onFinish: () {},
      ),
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

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxHeight: 700),
          child: FlashcardsView(
            title: _flashcardSet!.title,
            flashcards: flashcards,
            onReview: (index, knewIt) {},
            onFinish: () {},
          ),
        ),
      ),
    );
  }
}
