import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/theme/web_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/local_database_service.dart';
import '../../../services/spaced_repetition_service.dart';
import '../../../services/progress_service.dart';
import '../../../models/flashcard.dart';
import '../../../models/user_model.dart';
import '../../../models/daily_mission.dart';
import '../../../services/mission_service.dart';
import '../../../services/user_service.dart';
import '../../widgets/web/active_mission_card.dart';
import '../../widgets/web/streak_card.dart';
import '../../widgets/web/accuracy_card.dart';
import '../../widgets/web/review_list_card.dart';
import '../../widgets/web/focus_timer_card.dart';
import '../../widgets/web/daily_goal_card.dart';
import '../../widgets/web/interactive_preview_card.dart';

class ReviewScreenWeb extends StatefulWidget {
  const ReviewScreenWeb({super.key});

  @override
  State<ReviewScreenWeb> createState() => _ReviewScreenWebState();
}

class _ReviewScreenWebState extends State<ReviewScreenWeb> {
  DailyMission? _dailyMission;
  bool _isLoading = true;
  String? _error;
  DateTime? _nextReviewDate;
  int _dueCount = 0;
  double _accuracy = 0.0;
  int _dailyGoalMinutes = 60;
  int _timeSpentMinutes = 0;
  String _previewQuestion = "What is the 'event loop' in JavaScript?";

  // Study Session State
  bool _isStudying = false;
  List<Flashcard> _studyCards = [];
  int _currentCardIndex = 0;
  bool _isFlipped = false;
  int _correctCount = 0;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMission();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _loadMission() async {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "User not found.";
        });
      }
      return;
    }

    try {
      // Load mission
      final missionService =
          Provider.of<MissionService>(context, listen: false);
      final mission = await missionService.generateDailyMission(userId);

      // Load SRS stats
      final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
      await localDb.init();
      final srsService =
          SpacedRepetitionService(localDb.getSpacedRepetitionBox());
      final stats = await srsService.getStatistics(userId);
      final nextDate = srsService.getNextReviewDate(userId);

      // Load user progress stats
      final progressService = ProgressService();
      final avgAccuracy = await progressService.getAverageAccuracy(userId);
      final totalTimeSpent = await progressService.getTotalTimeSpent(userId);
      
      // Load user data for daily goal
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      int dailyGoal = 60; // Default
      int timeSpentToday = 0;
      String lastQuestion = "What is the 'event loop' in JavaScript?";

      if (userDoc.exists) {
        final userData = userDoc.data();
        dailyGoal = userData?['dailyGoal'] as int? ?? 60;
      }
      
      timeSpentToday = (totalTimeSpent / 60).round(); // Convert seconds to minutes

      // Fetch last flashcard for preview
      final sets = await localDb.getAllFlashcardSets(userId);
      if (sets.isNotEmpty && sets.first.flashcards.isNotEmpty) {
        lastQuestion = sets.first.flashcards.first.question;
      }

      if (mounted) {
        setState(() {
          _dailyMission = mission;
          _dueCount = stats['dueForReviewCount'] as int? ?? 0;
          _nextReviewDate = nextDate;
          _accuracy = avgAccuracy;
          _dailyGoalMinutes = dailyGoal;
          _timeSpentMinutes = timeSpentToday;
          _previewQuestion = lastQuestion;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Error loading dashboard: $e";
        });
      }
    }
  }

  Future<void> _fetchAndStartMission() async {
    if (_dailyMission == null) return;

    // If completed, just show nice message
    if (_dailyMission!.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("You've already completed today's mission! Great job!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      final localDb = Provider.of<LocalDatabaseService>(context, listen: false);

      if (userId == null) throw Exception("User ID null");

      // Fetch cards logic
      final sets = await localDb.getAllFlashcardSets(userId);
      final allCards = sets.expand((s) => s.flashcards).map((localCard) {
        return Flashcard(
          id: localCard.id,
          question: localCard.question,
          answer: localCard.answer,
        );
      }).toList();

      final cards = allCards
          .where((c) => _dailyMission!.flashcardIds.contains(c.id))
          .toList();

      if (cards.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Could not find mission cards. Using random cards instead.')));
          // Fallback to random cards if mission cards deleted
          _studyCards = allCards.take(5).toList();
        }
      } else {
        _studyCards = cards;
      }

      if (_studyCards.isEmpty) {
        throw Exception("No flashcards found to study.");
      }

      // Start Session
      _startStudySession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed to start: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  void _startStudySession() {
    setState(() {
      _isStudying = true;
      _isLoading = false;
      _currentCardIndex = 0;
      _isFlipped = false;
      _correctCount = 0;
    });
    _stopwatch.reset();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {}); // Update timer UI
    });
  }

  void _endStudySession() async {
    _stopwatch.stop();
    _timer?.cancel();

    if (_dailyMission != null && !_dailyMission!.isCompleted) {
      // Complete mission logic
      final userId =
          Provider.of<AuthService>(context, listen: false).currentUser?.uid;
      if (userId != null) {
        final missionService =
            Provider.of<MissionService>(context, listen: false);
        // Calculate score
        double score =
            _studyCards.isEmpty ? 0 : _correctCount / _studyCards.length;
        await missionService.completeMission(userId, _dailyMission!, score);

        final userService = UserService();
        await userService.incrementItemsCompleted(userId);

        await _loadMission(); // Reload to update UI
      }
    }

    setState(() {
      _isStudying =
          false; // Return to dashboard, but ideally show completion dialog first
    });

    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/web/success_illustration.png',
                height: 100),
            const SizedBox(height: 16),
            Text(
                'You got $_correctCount out of ${_studyCards.length} correct!'),
            Text('Time: ${_formatDuration(_stopwatch.elapsed)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  void _showMissionDetails(BuildContext context) {
    if (_dailyMission == null) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mission Details',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: WebColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _dailyMission?.title ?? 'Daily Mission',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete ${_dailyMission!.flashcardIds.length} quiz sets today to hit your XP target.',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: WebColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Progress: ${_dailyMission!.isCompleted ? _dailyMission!.flashcardIds.length : 0}/${_dailyMission!.flashcardIds.length} sets',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: WebColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
              onPressed: () {
                Navigator.pop(context);
                _fetchAndStartMission();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_dailyMission?.isCompleted == true ? 'Mission Completed' : 'Start Mission'),
            ),
          ],
        ),
      ),
    );
  }

  void _nextCard(bool known) {
    if (known) _correctCount++;

    if (_currentCardIndex < _studyCards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _isFlipped = false;
      });
    } else {
      _endStudySession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);

    if (_isStudying) {
      return _buildStudySession();
    }

    return Scaffold(
      backgroundColor: WebColors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: WebColors.primary))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: TextStyle(
                          color: WebColors.textPrimary, fontSize: 18)))
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          _buildHeader(user),
                          const SizedBox(height: 32),

                          // Top Row: Active Mission (2/3) + Stats (1/3)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: ActiveMissionCard(
                                  mission: _dailyMission,
                                  onStart: _fetchAndStartMission,
                                  onDetails: () {
                                    // Show mission details
                                    _showMissionDetails(context);
                                  },
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    StreakCard(
                                        streakDays:
                                            user?.missionCompletionStreak ?? 0),
                                    const SizedBox(height: 24),
                                    AccuracyCard(
                                        accuracy: _accuracy),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Middle Row: Due for Review + Daily Goal
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: ReviewListCard(
                                  dueCount: _dueCount,
                                  onReviewAll: () {
                                    // Navigate to spaced repetition screen
                                    context.push('/spaced-repetition');
                                  },
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 1,
                                child: DailyGoalCard(
                                  goalMinutes: _dailyGoalMinutes,
                                  timeSpentMinutes: _timeSpentMinutes,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Bottom Row: Focus Timer + Interactive Preview
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 1,
                                child: FocusTimerCard(),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: InteractivePreviewCard(
                                  question: _previewQuestion,
                                  onClipPressed: () {
                                    // Copy question to clipboard
                                    Clipboard.setData(ClipboardData(text: _previewQuestion));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Question copied to clipboard!'),
                                        backgroundColor: WebColors.success,
                                      ),
                                    );
                                  },
                                ),
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildHeader(UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_getGreeting()}, ${user?.displayName.split(' ').first ?? 'Scholar'}!',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: WebColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You\'re on a ${user?.missionCompletionStreak ?? 0}-day learning streak. Keep it up!',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: WebColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // --- Study Session UI ---

  Widget _buildStudySession() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [WebColors.background, Colors.white],
              ),
            ),
          ),

          Column(
            children: [
              // Top Bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 28),
                      onPressed: () {
                        _stopwatch.stop();
                        _timer?.cancel();
                        setState(() => _isStudying = false);
                      },
                      tooltip: 'Exit Session',
                      style: IconButton.styleFrom(
                        backgroundColor: WebColors.backgroundAlt,
                        foregroundColor: WebColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SESSION PROGRESS',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: WebColors.textTertiary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                '${_currentCardIndex + 1} / ${_studyCards.length}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: WebColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value:
                                  (_currentCardIndex + 1) / _studyCards.length,
                              backgroundColor: WebColors.backgroundAlt,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  WebColors.primary),
                              minHeight: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Glassmorphism Timer
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: WebColors.border),
                        boxShadow: WebColors.subtleShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 22, color: WebColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            _formatDuration(_stopwatch.elapsed),
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: WebColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Flashcard
              Center(
                child: _build3DFlashcard(),
              ),

              const Spacer(),

              // Controls
              Container(
                padding: const EdgeInsets.all(32),
                child: _isFlipped
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildControlButton(
                              Icons.close,
                              "Forgot",
                              Colors.red[100]!,
                              Colors.red,
                              () => _nextCard(false)),
                          const SizedBox(width: 32),
                          _buildControlButton(
                              Icons.check,
                              "Remembered",
                              Colors.green[100]!,
                              Colors.green,
                              () => _nextCard(true)),
                        ],
                      ).animate().fadeIn(duration: 200.ms)
                    : ElevatedButton.icon(
                        onPressed: () => setState(() => _isFlipped = true),
                        icon: const Icon(Icons.flip),
                        label: const Text('Show Answer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WebColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48, vertical: 24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build3DFlashcard() {
    return GestureDetector(
      onTap: () => setState(() => _isFlipped = !_isFlipped),
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: _isFlipped ? 180 : 0),
        duration: const Duration(milliseconds: 400),
        builder: (context, double val, child) {
          bool isBack = val >= 90;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(val * pi / 180),
            child: Container(
              width: 640,
              height: 420,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: WebColors.border.withOpacity(0.5)),
                boxShadow: isBack
                    ? [
                        BoxShadow(
                          color: WebColors.success.withOpacity(0.1),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ]
                    : WebColors.hoverShadow,
              ),
              child: isBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: _buildCardContent(
                          _studyCards[_currentCardIndex].answer, true),
                    )
                  : _buildCardContent(
                      _studyCards[_currentCardIndex].question, false),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardContent(String text, bool isAnswer) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isAnswer ? Colors.green[50] : WebColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isAnswer ? 'ANSWER' : 'QUESTION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isAnswer ? Colors.green : WebColors.primary,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: WebColors.textPrimary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
      IconData icon, String label, Color bg, Color fg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- Dashboard UI Helpers Removed ---

  Widget _buildSrsBanner(BuildContext context) {
    bool isDue = _dueCount > 0;
    String timeText = "";

    if (!isDue && _nextReviewDate != null) {
      final now = DateTime.now();
      final diff = _nextReviewDate!.difference(now);
      if (diff.inHours > 0) {
        timeText = "in ${diff.inHours}h ${diff.inMinutes % 60}m";
      } else if (diff.inMinutes > 0) {
        timeText = "in ${diff.inMinutes}m";
      } else {
        timeText = "any moment now";
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDue ? Colors.amber[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDue
                ? Colors.amber.withOpacity(0.3)
                : Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(isDue ? Icons.notifications_active : Icons.timer,
              color: isDue ? Colors.amber[700] : Colors.blue[700], size: 32),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDue ? '$_dueCount Reviews Due Now' : 'All Caught Up! ✓',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDue ? Colors.amber[900] : Colors.blue[900],
                  ),
                ),
                Text(
                  isDue
                      ? 'Review these items now to maintain long-term retention.'
                      : 'Your next scheduled review is $timeText.',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDue ? Colors.amber[800] : Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
          if (isDue)
            ElevatedButton(
              onPressed: () {
                // Navigate to SRS (not yet implemented for web specifically, but could use generic)
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("SRS for web coming soon!")));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Review Now',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(UserModel? user) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.checklist_rounded,
            value: '${user?.itemsCompletedToday ?? 0}',
            label: 'Items Completed Today',
            color: WebColors.secondary,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildStatCard(
            icon: Icons.timeline_rounded,
            value: 'Top 10%', // Placeholder
            label: 'Activity Ranking',
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildStatCard(
            icon: Icons.schedule_rounded,
            value: '25m', // Placeholder
            label: 'Study Time Today',
            color: const Color(0xFFEC4899),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: WebColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: WebColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
