import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';

class ProgressScreenWeb extends StatefulWidget {
  const ProgressScreenWeb({super.key});

  @override
  State<ProgressScreenWeb> createState() => _ProgressScreenWebState();
}

class _ProgressScreenWebState extends State<ProgressScreenWeb> {
  // Stats
  int _summariesCount = 0;
  int _quizzesCount = 0;
  int _flashcardsCount = 0;
  double _averageAccuracy = 0;
  List<FlSpot> _weeklyActivity = [];
  String _mostActiveDay = 'N/A';
  String _totalTimeDisplay = '0m';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final user = context.read<UserModel?>();
      if (user == null) return;

      final dbService = LocalDatabaseService();
      await dbService.init();

      // Fetch Local Data
      final summaries = await dbService.getAllSummaries(user.uid);
      final quizzes = await dbService.getAllQuizzes(user.uid);
      final flashcards = await dbService.getAllFlashcardSets(user.uid);

      // Calculate Quiz Stats
      double totalAccuracy = 0.0;
      int quizCountWithScores = 0;
      int totalSeconds = 0;

      for (var quiz in quizzes) {
        if (quiz.scores.isNotEmpty) {
          final avgQ = quiz.scores.reduce((a, b) => a + b) / quiz.scores.length;
          totalAccuracy += avgQ;
          quizCountWithScores++;
        }
        // Accumulate time spent
        totalSeconds += quiz.timeSpent;
      }

      final accuracy =
          quizCountWithScores > 0 ? totalAccuracy / quizCountWithScores : 0.0;

      // Calculate Weekly Activity locally
      final activity = _calculateWeeklyActivity(summaries, quizzes, flashcards);

      // Determine Most Active Day
      // activity is [Mon, Tue, ... Sun] (0..6) logic in _calculateWeeklyActivity?
      // Wait, _calculateWeeklyActivity implementation below uses diff from today.
      // diff 0 = Today. diff 1 = Yesterday.
      // So index 0 is Today, index 1 is Yesterday.
      // We need to map that back to day names.
      // Let's refine _calculateWeeklyActivity logic to be clear about indices.
      // Current implementation: `activity[diff]++` where diff is days ago.
      // So index 0 = Today, index 6 = 6 days ago.

      int maxActivityIndex = 0;
      double maxVal = -1;
      for (int i = 0; i < activity.length; i++) {
        if (activity[i].y > maxVal) {
          maxVal = activity[i].y;
          maxActivityIndex = i;
        }
      }

      // Map index (days ago) to Day Name
      final activeDate =
          DateTime.now().subtract(Duration(days: maxActivityIndex));
      // Simple day name
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      // DateTime.weekday: 1=Mon, 7=Sun.
      // days[weekday-1]
      String activeDayName = maxVal > 0 ? days[activeDate.weekday - 1] : 'None';

      // Format Time
      final minutes = (totalSeconds / 60).floor();
      final hours = (minutes / 60).floor();
      final displayTime =
          hours > 0 ? '${hours}h ${minutes % 60}m' : '${minutes}m';

      if (mounted) {
        setState(() {
          _summariesCount = summaries.length;
          _quizzesCount = quizzes.length;
          _flashcardsCount = flashcards.length;
          _averageAccuracy = accuracy;
          _weeklyActivity = activity;
          _mostActiveDay = activeDayName;
          _totalTimeDisplay = displayTime;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading stats: $e');
    }
  }

  List<FlSpot> _calculateWeeklyActivity(List<LocalSummary> summaries,
      List<LocalQuiz> quizzes, List<LocalFlashcardSet> flashcards) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    // 0 to 6 (7 days)
    final activity = List<double>.filled(7, 0);

    void processItems(List<dynamic> items) {
      for (var item in items) {
        final createdAt = item.timestamp as DateTime;
        final itemDate =
            DateTime(createdAt.year, createdAt.month, createdAt.day);
        final diff = startOfToday.difference(itemDate).inDays;

        if (diff >= 0 && diff < 7) {
          activity[diff]++;
        }
      }
    }

    processItems(summaries);
    processItems(quizzes);
    processItems(flashcards);

    // FlSpot(x, y) where x is index 0..6
    return List.generate(
        7, (index) => FlSpot(index.toDouble(), activity[index]));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your Progress",
                style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text("Track your learning journey and stats",
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 48),

            // Top Stats Row
            Row(
              children: [
                _buildStatCard("Total Summaries", _summariesCount.toString(),
                    Icons.article_outlined, Colors.blue, theme),
                const SizedBox(width: 24),
                _buildStatCard("Quizzes Taken", _quizzesCount.toString(),
                    Icons.quiz_outlined, Colors.orange, theme),
                const SizedBox(width: 24),
                _buildStatCard("Flashcards", _flashcardsCount.toString(),
                    Icons.view_carousel_outlined, Colors.purple, theme),
                const SizedBox(width: 24),
                _buildStatCard(
                    "Avg. Accuracy",
                    "${(_averageAccuracy * 100).toStringAsFixed(1)}%",
                    Icons.show_chart,
                    Colors.green,
                    theme),
              ],
            ),

            const SizedBox(height: 40),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildActivityChart(theme),
                ),
                const SizedBox(width: 24),
                // Insight Column
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 400,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10)
                        ]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Quick Insights",
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        _buildInsightRow(
                            "Most Active Day", _mostActiveDay, theme),
                        _buildInsightRow(
                            "Total Study Time", _totalTimeDisplay, theme),
                        _buildInsightRow(
                            "Learning Streak",
                            "${Provider.of<UserModel?>(context)?.missionCompletionStreak ?? 0} Days",
                            theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
            ]),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6))),
              ],
            ),
          ],
        ),
      )
          .animate()
          .scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildActivityChart(ThemeData theme) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Weekly Activity",
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        // meta required here
                        const days = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ];
                        // Simple mapping, ideally match actual dates from data
                        if (value.toInt() >= 0 && value.toInt() < 7) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(days[value.toInt()],
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                    fontSize: 12)),
                          );
                        }
                        return const Text('');
                      },
                      interval: 1,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _weeklyActivity, // Using fetched data
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildInsightRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
