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
      backgroundColor: WebColors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: WebColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(user),
                      const SizedBox(height: 48),
                      // Stats Grid
                      LayoutBuilder(builder: (context, constraints) {
                        return Row(
                          children: [
                            Expanded(
                                child: _buildStatCard(
                                    'Study Materials',
                                    '$_totalItems',
                                    Icons.library_books,
                                    Colors.blue)),
                            const SizedBox(width: 24),
                            Expanded(
                                child: _buildStatCard(
                                    'Quizzes Created',
                                    '$_totalQuizzes',
                                    Icons.quiz,
                                    Colors.orange)),
                            const SizedBox(width: 24),
                            Expanded(
                                child: _buildStatCard(
                                    'Flashcard Sets',
                                    '$_totalFlashcards',
                                    Icons.style,
                                    Colors.pink)),
                            const SizedBox(width: 24),
                            Expanded(
                                child: _buildStatCard(
                                    'Items Today',
                                    '${user?.itemsCompletedToday ?? 0}',
                                    Icons.check_circle,
                                    Colors.green)),
                          ],
                        );
                      }),

                      const SizedBox(height: 40),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildActivityChart(),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 1,
                            child: _buildStreaksCard(user),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [WebColors.primary, const Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: WebColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'YOUR PROGRESS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Keep up the great work!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are building a consistent learning habit. Check out your stats below.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/images/web/achievement_illustration.png',
            width: 180,
            height: 180,
            fit: BoxFit.contain,
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: WebColors.textPrimary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: WebColors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildActivityChart() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Activity',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: WebColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Your learning consistency over time',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: WebColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: WebColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WebColors.primary.withOpacity(0.1)),
                ),
                child: Text(
                  'LAST 7 DAYS',
                  style: GoogleFonts.outfit(
                      color: WebColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                maxY: (_weeklyActivity.reduce((a, b) => a > b ? a : b) + 5)
                    .toDouble(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => WebColors.textPrimary,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rod.toY.round().toString(),
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        // Calculate day labels dynamically based on today
                        final now = DateTime.now();
                        // Value 0 is 6 days ago
                        final date =
                            now.subtract(Duration(days: 6 - value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('E').format(date), // Mon, Tue...
                            style: TextStyle(
                              color: WebColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value % 5 != 0) return Container();
                        return Text(value.toInt().toString(),
                            style: TextStyle(
                                color: WebColors.textTertiary, fontSize: 12));
                      },
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: WebColors.border,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  7,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: _weeklyActivity[index].toDouble(),
                        gradient: LinearGradient(
                          colors: [
                            WebColors.primary,
                            WebColors.primary.withOpacity(0.6)
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildStreaksCard(UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department,
                  color: Colors.deepOrange, size: 28),
              const SizedBox(width: 12),
              Text(
                'Streak Stats',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: WebColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value:
                        1.0, // Always full for impact, or calculate streak strength
                    strokeWidth: 12,
                    color: Colors.deepOrange.withOpacity(0.1),
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: (user?.missionCompletionStreak ?? 0) /
                        30, // Example: 30 day goal
                    strokeWidth: 12,
                    color: Colors.deepOrange,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${user?.missionCompletionStreak ?? 0}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Colors.deepOrange,
                      ),
                    ),
                    Text(
                      'DAYS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Keep your streak alive by completing a Daily Mission every day!',
            style: TextStyle(color: WebColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }
}
