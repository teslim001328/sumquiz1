import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:intl/intl.dart';

class ProgressScreenWeb extends StatefulWidget {
  const ProgressScreenWeb({super.key});

  @override
  State<ProgressScreenWeb> createState() => _ProgressScreenWebState();
}

class _ProgressScreenWebState extends State<ProgressScreenWeb> {
  int _totalItems = 0;
  int _totalQuizzes = 0;
  int _totalFlashcards = 0;
  int _itemsCreated = 1284;
  double _studyTime = 42.5;
  int _dayStreak = 12;
  int _milestoneProgress = 750;
  int _milestoneGoal = 1000;
  // Weekly activity: Index 0 is Today, Index 6 is 6 days ago (reversed for chart usually)
  // Let's store as: Index 0 = 6 days ago, Index 6 = Today (Left to Right)
  List<int> _weeklyActivity = List.filled(7, 0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = context.read<UserModel?>();
    if (user == null) return;

    final db = context.read<LocalDatabaseService>();

    try {
      final summaries = await db.getAllSummaries(user.uid);
      final quizzes = await db.getAllQuizzes(user.uid);
      final flashcards = await db.getAllFlashcardSets(user.uid);

      setState(() {
        _totalItems = summaries.length;
        _totalQuizzes = quizzes.length;
        _totalFlashcards = flashcards.length;
        _weeklyActivity =
            _calculateWeeklyActivity(summaries, quizzes, flashcards);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Returns list where Index 0 is 6 days ago, Index 6 is Today
  List<int> _calculateWeeklyActivity(List<LocalSummary> summaries,
      List<LocalQuiz> quizzes, List<LocalFlashcardSet> flashcards) {
    final activity = List.filled(7, 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // Strip time

    void processItems(List<dynamic> items) {
      for (var item in items) {
        final itemDate = item.timestamp;
        final date = DateTime(itemDate.year, itemDate.month, itemDate.day);

        final daysDiff = today.difference(date).inDays;

        if (daysDiff >= 0 && daysDiff < 7) {
          // Index 6 is Today (diff 0), Index 0 is 6 days ago (diff 6)
          // i = 6 - diff
          activity[6 - daysDiff]++;
        }
      }
    }

    processItems(summaries);
    processItems(quizzes);
    processItems(flashcards);

    return activity;
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: WebColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopHeader(user),
                      const SizedBox(height: 32),
                      _buildStatsRow(),
                      const SizedBox(height: 32),
                      _buildMainContent(),
                      const SizedBox(height: 32),
                      _buildAchievementsSection(),
                      const SizedBox(height: 40),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTopHeader(UserModel? user) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Keep it up, Alex! 👏',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'re on track to hit your weekly learning goals.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF6B5CE7),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEAEAEA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Text(
                    'Last 7 Days',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6B5CE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Start New Quiz',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStreakCard()),
        const SizedBox(width: 24),
        Expanded(child: _buildGoalCompletionCard()),
      ],
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department, color: Color(0xFF6B5CE7), size: 24),
              ),
              const Spacer(),
              Row(
                children: List.generate(4, (index) => 
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index < 3 ? const Color(0xFF6B5CE7) : const Color(0xFFEAEAEA),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '$_dayStreak',
            style: GoogleFonts.outfit(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: WebColors.textPrimary,
              letterSpacing: -2,
            ),
          ),
          Text(
            'DAY STREAK',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B5CE7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You\'re in the top 5% of learners this week! Keep the flame alive.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF6B5CE7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCompletionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEE9FE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ITEMS COMPLETED TODAY',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6B5CE7),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Daily Goal Completion',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: WebColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '85% Complete',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B5CE7),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '17/20',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.85,
              backgroundColor: const Color(0xFFEAEAEA),
              color: const Color(0xFF6B5CE7),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetricBox('Total Created', '$_itemsCreated', Icons.edit, const Color(0xFFBFDBFE)),
              const SizedBox(width: 16),
              _buildMetricBox('Study Time', '${_studyTime}hrs', Icons.access_time, const Color(0xFFFED7AA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, IconData icon, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: bgColor == const Color(0xFFBFDBFE) ? const Color(0xFF3B82F6) : const Color(0xFFF97316)),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: WebColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF6B5CE7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildWeeklyActivity()),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              _buildMilestoneCard(),
              const SizedBox(height: 24),
              _buildQuickTipCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Activity',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: WebColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .asMap()
                .entries
                .map((entry) => Column(
                      children: [
                        Text(
                          entry.value,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: entry.key == 3 ? FontWeight.w600 : FontWeight.w400,
                            color: entry.key == 3 ? const Color(0xFF6B5CE7) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: entry.key == 3 ? const Color(0xFF6B5CE7) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: entry.key == 3 ? null : Border.all(color: const Color(0xFFEAEAEA)),
                          ),
                        ),
                      ],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Stack(
        children: [
          // Trophy watermark
          Positioned(
            right: 10,
            top: 10,
            child: Opacity(
              opacity: 0.05,
              child: Transform.rotate(
                angle: 0.3,
                child: const Icon(Icons.emoji_events, size: 80, color: Color(0xFF6B5CE7)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, color: Color(0xFF6B5CE7), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'NEXT MILESTONE',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B5CE7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Knowledge Master II',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete 250 more quiz items to unlock this badge.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFF6B5CE7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _milestoneProgress / _milestoneGoal,
                  backgroundColor: const Color(0xFFEAEAEA),
                  color: const Color(0xFF6B5CE7),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_milestoneProgress/$_milestoneGoal Items',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTipCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFF3C4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Color(0xFFFACC15), size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick Tip',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFCA8A04),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Taking short breaks every 25 minutes helps maintain high levels of focus. Try the Pomodoro technique for your next session!',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFFCA8A04),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Achievements',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: WebColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _buildAchievementCard('Quick Learner', '10 quizzes in 24h', Icons.autorenew, const Color(0xFF6B5CE7)),
            const SizedBox(width: 16),
            _buildAchievementCard('Perfect Score', '100% on Advance Tech', Icons.check_circle, const Color(0xFF22C55E)),
            const SizedBox(width: 16),
            _buildAchievementCard('Community Ace', 'Shared 5 study sets', Icons.people, const Color(0xFF3B82F6)),
            const SizedBox(width: 16),
            _buildAchievementCard('Early Bird', 'Studied before 7 AM', Icons.wb_sunny, const Color(0xFFEC4899)),
          ],
        ),
      ],
    );
  }

  Widget _buildAchievementCard(String title, String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEAEAEA)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WebColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Text(
            'SumQuiz',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B5CE7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '© 2024 Learning Analytics',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Documentation | Privacy | Support',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
