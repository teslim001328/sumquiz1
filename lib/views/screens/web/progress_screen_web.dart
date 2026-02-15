import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/services/progress_service.dart';

class ProgressScreenWeb extends StatefulWidget {
  const ProgressScreenWeb({super.key});

  @override
  State<ProgressScreenWeb> createState() => _ProgressScreenWebState();
}

class _ProgressScreenWebState extends State<ProgressScreenWeb> {
  int _totalItems = 0;
  int _itemsCreated = 0;
  double _studyTime = 0;
  int _dayStreak = 0;
  int _milestoneProgress = 0;
  int _milestoneGoal = 100;
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
    final progressService = ProgressService();

    try {
      final summariesCount = await progressService.getSummariesCount(user.uid);
      final quizzesCount = await progressService.getQuizzesCount(user.uid);
      final flashcardsCount = await progressService.getFlashcardsCount(user.uid);
      final totalSeconds = await progressService.getTotalTimeSpent(user.uid);
      final summaries = await db.getAllSummaries(user.uid);
      final quizzes = await db.getAllQuizzes(user.uid);
      final flashcards = await db.getAllFlashcardSets(user.uid);

      setState(() {
        _totalItems = summaries.length + summariesCount;
        _itemsCreated = _totalItems + quizzes.length + quizzesCount + flashcards.length + flashcardsCount;
        _studyTime = totalSeconds / 3600; // to hours
        _dayStreak = user.missionCompletionStreak;
        _milestoneProgress = _itemsCreated % 100;
        _milestoneGoal = 100;
        _weeklyActivity =
            _calculateWeeklyActivity(summaries, quizzes, flashcards);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<int> _calculateWeeklyActivity(List<LocalSummary> summaries,
      List<LocalQuiz> quizzes, List<LocalFlashcardSet> flashcards) {
    final activity = List.filled(7, 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    void processItems(List<dynamic> items) {
      for (var item in items) {
        final itemDate = item.timestamp;
        final date = DateTime(itemDate.year, itemDate.month, itemDate.day);
        final daysDiff = today.difference(date).inDays;
        if (daysDiff >= 0 && daysDiff < 7) {
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
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
                'Keep it up, ${user?.displayName.split(' ').first ?? 'Student'}! 👏',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).textTheme.headlineMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'re on track to hit your weekly learning goals.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary.withAlpha(179),
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
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
                color: Theme.of(context).colorScheme.primary,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_fire_department, color: Theme.of(context).colorScheme.primary, size: 24),
              ),
              const Spacer(),
              Row(
                children: List.generate(4, (index) => 
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index < 3 ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
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
              color: Theme.of(context).textTheme.headlineMedium?.color,
              letterSpacing: -2,
            ),
          ),
          Text(
            'DAY STREAK',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You\'re in the top 5% of learners this week! Keep the flame alive.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Theme.of(context).colorScheme.primary.withAlpha(204),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ITEMS COMPLETED TODAY',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
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
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${((_totalItems % 20) / 20.0 * 100).round()}% Complete',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_totalItems % 20}/20',
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
              value: (_totalItems % 20) / 20.0,
              backgroundColor: Theme.of(context).dividerColor,
              color: Theme.of(context).colorScheme.primary,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetricBox('Total Created', '$_itemsCreated', Icons.edit, Colors.blue),
              const SizedBox(width: 16),
              _buildMetricBox('Study Time', '${_studyTime.toStringAsFixed(1)}hrs', Icons.access_time, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(51)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Activity',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (_weeklyActivity.reduce((a, b) => a > b ? a : b) + 1).toDouble(),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final now = DateTime.now();
                        final date = now.subtract(Duration(days: 6 - value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[date.weekday - 1],
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: value.toInt() == 6 ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodySmall?.color,
                                fontWeight: value.toInt() == 6 ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _weeklyActivity[i].toDouble(),
                        color: i == 6 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withAlpha(77),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 10,
            top: 10,
            child: Opacity(
              opacity: 0.05,
              child: Transform.rotate(
                angle: 0.3,
                child: Icon(Icons.emoji_events, size: 80, color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'NEXT MILESTONE',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
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
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete ${(_milestoneGoal - _milestoneProgress).toInt()} more items to unlock this badge.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _milestoneProgress / _milestoneGoal,
                  backgroundColor: Theme.of(context).dividerColor,
                  color: Theme.of(context).colorScheme.primary,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_milestoneProgress/$_milestoneGoal Items',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
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
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 20),
        _buildRecentAchievements(),
      ],
    );
  }

  Widget _buildRecentAchievements() {
    final user = Provider.of<UserModel?>(context);
    final totalItems = user?.totalDecksGenerated ?? 0;
    final streak = user?.missionCompletionStreak ?? 0;

    return Row(
      children: [
        _buildAchievementCard(
          totalItems >= 50 ? 'Knowledge Master' : 'Scholar in Training',
          '$totalItems items curated',
          Icons.school,
          totalItems >= 50 ? Colors.amber : Colors.blueGrey,
        ),
        const SizedBox(width: 16),
        _buildAchievementCard(
          _studyTime >= 10 ? 'Deep Learner' : 'Consistent Learner',
          '${_studyTime.toStringAsFixed(1)} hours study',
          Icons.timer_outlined,
          _studyTime >= 10 ? Colors.orange : Colors.blue,
        ),
        const SizedBox(width: 16),
        _buildAchievementCard(
          streak >= 7 ? 'Legendary Streak' : 'Rising Star',
          '$streak day streak',
          Icons.bolt,
          streak >= 7 ? Colors.purple : Colors.teal,
        ),
      ],
    );
  }

  Widget _buildAchievementCard(String title, String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
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
                color: Theme.of(context).textTheme.titleSmall?.color,
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
              color: Theme.of(context).colorScheme.primary,
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
