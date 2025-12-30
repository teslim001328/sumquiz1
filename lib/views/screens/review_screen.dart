import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../services/local_database_service.dart'; // Changed to LocalDatabaseService
import '../../models/flashcard.dart';
import '../../models/flashcard_set.dart';
import '../../models/user_model.dart';
import '../../models/daily_mission.dart';
import '../../services/mission_service.dart';
import '../../services/user_service.dart';
import 'flashcards_screen.dart';
import 'summary_screen.dart';
import 'quiz_screen.dart';
import '../../models/local_summary.dart';
import '../../models/local_quiz.dart';
import '../../models/local_flashcard_set.dart';
import 'package:rxdart/rxdart.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  DailyMission? _dailyMission;
  bool _isLoading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMission();
  }

  Future<void> _loadMission() async {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = "User not found.";
      });
      return;
    }

    try {
      final missionService =
          Provider.of<MissionService>(context, listen: false);
      final mission = await missionService.generateDailyMission(userId);

      // Also fetch user model to show updated momentum if needed
      // (StreamProvider in main might handle this, but explicit fetch is safe)

      setState(() {
        _dailyMission = mission;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Error loading mission: $e";
      });
    }
  }

  Future<List<Flashcard>> _fetchMissionCards(List<String> cardIds) async {
    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId == null) return [];

    final localDb = Provider.of<LocalDatabaseService>(context, listen: false);

    // Fetch all local sets
    final sets = await localDb.getAllFlashcardSets(userId);

    // Flatten and Map LocalFlashcard -> Flashcard
    final allCards = sets.expand((s) => s.flashcards).map((localCard) {
      return Flashcard(
        id: localCard.id,
        question: localCard.question,
        answer: localCard.answer,
      );
    }).toList();

    return allCards.where((c) => cardIds.contains(c.id)).toList();
  }

  Future<void> _startMission() async {
    if (_dailyMission == null) return;

    setState(() => _isLoading = true);

    try {
      final cards = await _fetchMissionCards(_dailyMission!.flashcardIds);

      if (cards.isEmpty) {
        // Fallback: If for some reason cards are missing (deleted?), warn user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Could not find mission cards. They might be deleted.')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      setState(() => _isLoading = false);

      if (!mounted) return;

      final reviewSet = FlashcardSet(
        id: 'mission_session',
        title: 'Daily Mission',
        flashcards: cards,
        timestamp: Timestamp.now(),
      );

      // Navigate
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlashcardsScreen(flashcardSet: reviewSet),
        ),
      );

      // Handle Result (Score)
      if (result != null && result is double) {
        await _completeMission(result);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Failed to start mission: $e";
      });
    }
  }

  Future<void> _completeMission(double score) async {
    if (_dailyMission == null) return;

    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId == null) return;

    final missionService = Provider.of<MissionService>(context, listen: false);
    await missionService.completeMission(userId, _dailyMission!, score);

    // Increment user's completed items for the day
    final userService = UserService();
    await userService.incrementItemsCompleted(userId);

    // Reload state
    _loadMission();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use user model from provider if available for current Momentum display
    final user = Provider.of<UserModel?>(context); // StreamProvider in main

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Study Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildMissionDashboard(theme, user),
    );
  }

  Widget _buildMissionDashboard(ThemeData theme, UserModel? user) {
    if (_dailyMission == null) return const SizedBox();

    final isCompleted = _dailyMission!.isCompleted;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Momentum Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Momentum', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      (user?.currentMomentum ?? 0).toStringAsFixed(0),
                      style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Icon(Icons.local_fire_department,
                    color: Colors.orange, size: 32),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Daily Goal Progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Daily Goal', style: theme.textTheme.titleMedium),
                    Text(
                        '${user?.itemsCompletedToday ?? 0}/${user?.dailyGoal ?? 5} items',
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (user?.dailyGoal ?? 5) > 0
                      ? ((user?.itemsCompletedToday ?? 0) /
                              (user?.dailyGoal ?? 5))
                          .clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: theme.dividerColor,
                  color: ((user?.itemsCompletedToday ?? 0) >=
                          (user?.dailyGoal ?? 5))
                      ? Colors.green
                      : theme.colorScheme.primary,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  ((user?.itemsCompletedToday ?? 0) >= (user?.dailyGoal ?? 5))
                      ? '🎉 Goal achieved!'
                      : '${(((user?.itemsCompletedToday ?? 0) / (user?.dailyGoal ?? 5)) * 100).toStringAsFixed(0)}% complete',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ((user?.itemsCompletedToday ?? 0) >=
                            (user?.dailyGoal ?? 5))
                        ? Colors.green
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mission Card
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
                border: isCompleted
                    ? Border.all(color: Colors.green, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isCompleted ? Icons.check_circle : Icons.rocket_launch,
                      size: 60,
                      color: isCompleted
                          ? Colors.green
                          : theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    isCompleted ? 'Mission Complete!' : "Today's Mission",
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (!isCompleted) ...[
                    _buildMissionDetail(theme, Icons.timelapse,
                        "${_dailyMission!.estimatedTimeMinutes} min"),
                    const SizedBox(height: 4),
                    _buildMissionDetail(theme, Icons.filter_none,
                        "${_dailyMission!.flashcardIds.length} cards"),
                    const SizedBox(height: 4),
                    _buildMissionDetail(theme, Icons.speed,
                        "Reward: +${_dailyMission!.momentumReward}"),
                  ] else ...[
                    Text(
                      "Great job! You've kept your momentum alive.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Score: ${(_dailyMission!.completionScore * 100).toStringAsFixed(0)}%",
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          isCompleted ? null : _startMission, // Disable if done
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isCompleted
                            ? Colors.grey
                            : theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        isCompleted ? 'Come back tomorrow' : 'Start Mission',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Recent Activity Header
          Text('Jump Back In',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // Recent Activity List
          Expanded(
            flex: 1,
            child: _buildRecentActivity(theme, user),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(ThemeData theme, UserModel? user) {
    if (user == null) return const SizedBox();
    final localDb = Provider.of<LocalDatabaseService>(context, listen: false);

    return StreamBuilder(
      stream: Rx.combineLatest3(
        localDb.watchAllFlashcardSets(user.uid),
        localDb.watchAllQuizzes(user.uid),
        localDb.watchAllSummaries(user.uid),
        (sets, quizzes, summaries) {
          final all = <dynamic>[...sets, ...quizzes, ...summaries];
          all.sort(
              (a, b) => b.timestamp.compareTo(a.timestamp)); // Sort descending
          return all.take(5).toList(); // Take top 5
        },
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data as List<dynamic>;

        if (items.isEmpty) {
          return Center(
              child: Text('No recent activity',
                  style: theme.textTheme.bodyMedium));
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            String title = item.title;
            IconData icon = Icons.article;
            Color color = Colors.blue;
            String type = 'Summary';

            if (item is LocalFlashcardSet) {
              icon = Icons.style;
              color = Colors.orange;
              type = 'Flashcards';
            } else if (item is LocalQuiz) {
              icon = Icons.quiz;
              color = Colors.green;
              type = 'Quiz';
            }

            return Container(
              width: 160,
              margin: const EdgeInsets.only(right: 12),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  onTap: () {
                    if (item is LocalFlashcardSet) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FlashcardsScreen(
                                  flashcardSet: FlashcardSet(
                                      id: item.id,
                                      title: item.title,
                                      flashcards: item.flashcards
                                          .map((f) => Flashcard(
                                              id: f.id,
                                              question: f.question,
                                              answer: f.answer))
                                          .toList(),
                                      timestamp: Timestamp.fromDate(
                                          item.timestamp)))));
                    } else if (item is LocalQuiz) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => QuizScreen(quiz: item)));
                    } else if (item is LocalSummary) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SummaryScreen(summary: item)));
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: color.withOpacity(0.1),
                          child: Icon(icon, color: color),
                        ),
                        const Spacer(),
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(type, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMissionDetail(ThemeData theme, IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(text, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}
