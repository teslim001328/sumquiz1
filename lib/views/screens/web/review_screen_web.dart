import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/theme/web_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/local_database_service.dart';
import '../../../models/flashcard.dart';
import '../../../models/flashcard_set.dart';
import '../../../models/user_model.dart';
import '../../../models/daily_mission.dart';
import '../../../services/mission_service.dart';
import '../../../services/user_service.dart';

class ReviewScreenWeb extends StatefulWidget {
  const ReviewScreenWeb({super.key});

  @override
  State<ReviewScreenWeb> createState() => _ReviewScreenWebState();
}

class _ReviewScreenWebState extends State<ReviewScreenWeb> {
  DailyMission? _dailyMission;
  bool _isLoading = true;
  String? _error;

  // Study Session State
  bool _isStudying = false;
  List<Flashcard> _studyCards = [];
  int _currentCardIndex = 0;
  bool _isFlipped = false;
  int _correctCount = 0;
  Stopwatch _stopwatch = Stopwatch();
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
      if (mounted)
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

      if (mounted)
        setState(() {
          _dailyMission = mission;
          _isLoading = false;
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _error = "Error loading mission: $e";
        });
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
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeHeader(user),
                          const SizedBox(height: 48),
                          _buildDailyMissionCard(),
                          const SizedBox(height: 32),
                          _buildStatsOverview(user),
                        ],
                      ),
                    ),
                  ),
                ),
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
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _stopwatch.stop();
                        _timer?.cancel();
                        setState(() => _isStudying = false);
                      },
                      tooltip: 'Exit Session',
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_currentCardIndex + 1) / _studyCards.length,
                          backgroundColor: Colors.grey[200],
                          color: WebColors.primary,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_stopwatch.elapsed),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace'),
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
              width: 600,
              height: 400,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: WebColors.primary.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
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

  // --- Dashboard UI ---

  Widget _buildWelcomeHeader(UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${user?.displayName.split(' ').first ?? 'Friend'}! 👋',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: WebColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ready to crush your daily mission?',
                    style: TextStyle(
                      fontSize: 18,
                      color: WebColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: WebColors.accentOrange),
                  const SizedBox(width: 8),
                  Text(
                    '${user?.missionCompletionStreak ?? 0} Day Streak',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: WebColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildDailyMissionCard() {
    if (_dailyMission == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.cardShadow,
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
                    color: WebColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🎯 DAILY MISSION',
                    style: TextStyle(
                      color: WebColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Review 5 Flashcards',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: WebColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _dailyMission!.isCompleted
                      ? 'You have completed your daily mission!'
                      : 'Complete today\'s mission to maintain your streak',
                  style: TextStyle(
                    fontSize: 16,
                    color: WebColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed:
                      _dailyMission!.isCompleted ? null : _fetchAndStartMission,
                  icon: Icon(
                      _dailyMission!.isCompleted
                          ? Icons.check_circle
                          : Icons.play_arrow,
                      color: Colors.white),
                  label: Text(
                    _dailyMission!.isCompleted
                        ? 'Mission Completed! 🎉'
                        : 'Start Mission',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dailyMission!.isCompleted
                        ? WebColors.secondary
                        : WebColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 22,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: WebColors.primary.withOpacity(0.4),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .shimmer(duration: 2.seconds, delay: 1.seconds),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Image.asset(
            'assets/images/web/study_illustration.png',
            width: 250,
            height: 250,
            fit: BoxFit.contain,
          ).animate().scale(duration: 400.ms, curve: Curves.easeInOutBack),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
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
