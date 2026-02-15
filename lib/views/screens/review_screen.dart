import 'dart:ui';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../../services/auth_service.dart';
import '../../services/local_database_service.dart';
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
import 'package:sumquiz/views/screens/spaced_repetition_screen.dart';
import '../../services/spaced_repetition_service.dart';
import 'package:rxdart/rxdart.dart';
import 'exam_creation_screen.dart';
import '../../services/content_extraction_service.dart';
import '../widgets/extraction_progress_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  DailyMission? _dailyMission;
  bool _isLoading = true;
  String? _error;
  int _dueCount = 0;
  DateTime? _nextReviewDate;
  double _masteryScore = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    // Load both mission and SRS stats concurrently
    await Future.wait([
      _loadMission(),
      _loadSrsStats(),
    ]);
  }

  Future<void> _loadSrsStats() async {
    if (!mounted) return;
    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId == null) return;

    try {
      final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
      await localDb.init();
      final srsService =
          SpacedRepetitionService(localDb.getSpacedRepetitionBox());
      final stats = await srsService.getStatistics(userId);
      final nextDate = srsService.getNextReviewDate(userId);
      final mastery = srsService.getMasteryScore(userId);

      if (mounted) {
        setState(() {
          _dueCount = stats['dueForReviewCount'] as int? ?? 0;
          _nextReviewDate = nextDate;
          _masteryScore = mastery;
        });
      }
    } catch (e) {
      developer.log('Error loading SRS stats', error: e);
    }
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
    final sets = await localDb.getAllFlashcardSets(userId);

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
    if (_dailyMission == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No mission available. Please create some study content first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cards = await _fetchMissionCards(_dailyMission!.flashcardIds);

      if (cards.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not find mission cards. They might be deleted.\nPlease create new study content.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
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

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlashcardsScreen(flashcardSet: reviewSet),
        ),
      );

      if (result != null && result is double && mounted) {
        await _completeMission(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to start mission: $e";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Error starting mission: ${e.toString().split(':').first}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _completeMission(double score) async {
    if (_dailyMission == null) return;

    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId == null) return;

    final missionService = Provider.of<MissionService>(context, listen: false);
    await missionService.completeMission(userId, _dailyMission!, score);

    final userService = UserService();
    await userService.incrementItemsCompleted(userId);

    _loadMission();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Dashboard',
            style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A237E))),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings,
                color: isDark ? Colors.white : const Color(0xFF1A237E)),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        activeBackgroundColor: theme.colorScheme.primaryContainer,
        activeForegroundColor: theme.colorScheme.onPrimaryContainer,
        spacing: 12,
        spaceBetweenChildren: 8,
        tooltip: 'Create New Content',
        children: [
          SpeedDialChild(
            child: const Icon(Icons.school),
            label: 'Tutor/Teacher Exam',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamCreationScreen()),
            ),
          ),
          SpeedDialChild(
            child: const Icon(Icons.picture_as_pdf),
            label: 'Upload Doc',
            onTap: () => _pickAndExtractFile(['pdf', 'doc', 'docx', 'ppt', 'pptx']),
          ),
          SpeedDialChild(
            child: const Icon(Icons.link),
            label: 'Analyze Link',
            onTap: _showLinkDialog,
          ),
          SpeedDialChild(
            child: const Icon(Icons.camera_alt),
            label: 'Image/Snap',
            onTap: () => _pickAndExtractImage(ImageSource.camera),
          ),
          SpeedDialChild(
            child: const Icon(Icons.audiotrack),
            label: 'Audio',
            onTap: () => _pickAndExtractFile(['mp3', 'wav', 'm4a']),
          ),
          SpeedDialChild(
            child: const Icon(Icons.text_fields),
            label: 'Paste Text',
            onTap: _showPasteTextDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated Background
          Animate(
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: [
              CustomEffect(
                duration: 6.seconds,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF0F172A),
                                Color.lerp(const Color(0xFF0F172A),
                                    const Color(0xFF1E293B), value)!
                              ]
                            : [
                                const Color(0xFFF3F4F6),
                                Color.lerp(const Color(0xFFE8EAF6),
                                    const Color(0xFFC5CAE9), value)!
                              ],
                      ),
                    ),
                    child: child,
                  );
                },
              )
            ],
            child: Container(),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!, style: theme.textTheme.bodyMedium))
                    : _buildMissionDashboard(user, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionDashboard(UserModel? user, ThemeData theme) {
    // Show helpful message if mission is null instead of blank screen
    if (_dailyMission == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildGlassCard(
            theme: theme,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                        theme.colorScheme.secondary.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 64, color: theme.colorScheme.primary),
                ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                const SizedBox(height: 32),
                Text(
                  'Your Learning Journey Awaits',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),
                Text(
                  'Transform any content into personalized study materials.\nStart by summarizing a document or article.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/create'),
                    icon: const Icon(Icons.auto_awesome, size: 24),
                    label: const Text('Generate My First Mission',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ).animate().scale(delay: 600.ms),
              ],
            ),
          ),
        ),
      );
    }
    final isCompleted = _dailyMission!.isCompleted;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Premium Welcome Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.colorScheme.secondary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child:
                      Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        user?.displayName ?? 'Learner',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          color: Colors.amber[700], size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${user?.missionCompletionStreak ?? 0} day streak',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideX(),

          const SizedBox(height: 24),

          // SRS Banner
          _buildSrsBanner(theme),
          const SizedBox(height: 24),

          // Premium Mastery Overview
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Circular progress with enhanced styling
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                            theme.colorScheme.secondary.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 70,
                      width: 70,
                      child: CircularProgressIndicator(
                        value: _masteryScore / 100,
                        strokeWidth: 8,
                        color: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.auto_awesome_rounded,
                          color: theme.colorScheme.primary, size: 28),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Knowledge Mastery',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.8))),
                      const SizedBox(height: 8),
                      Text(
                          '${_masteryScore.toStringAsFixed(1)}% Overall Proficiency',
                          style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _masteryScore / 100,
                        backgroundColor: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.2),
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                        minHeight: 8,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: TextButton(
                    onPressed: () => context.push('/progress'),
                    child: const Text('View Insights',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideX(),

          const SizedBox(height: 24),

          // Premium Stats Row
          Row(
            children: [
              Expanded(
                child: _buildPremiumStatCard(
                  title: 'Learning Momentum',
                  value: (user?.currentMomentum ?? 0).toStringAsFixed(0),
                  subtitle: 'XP Points',
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orange,
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.deepOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  theme: theme,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildPremiumGoalCard(user, theme),
              ),
            ],
          ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

          const SizedBox(height: 24),

          // Mission Card
          _buildMissionCard(isCompleted, theme),

          const SizedBox(height: 32),

          // Recent Activity
          Text('Jump Back In',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: _buildRecentActivity(user, theme),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGlassCard(
      {required Widget child,
      EdgeInsets? padding,
      Color? borderColor,
      required ThemeData theme}) {
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: isDark ? 0.5 : 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: borderColor ?? theme.dividerColor.withValues(alpha: 0.2),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPremiumStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required LinearGradient gradient,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          Text(value,
              style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text(title,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
          Text(subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildPremiumGoalCard(UserModel? user, ThemeData theme) {
    final current = user?.itemsCompletedToday ?? 0;
    final target = user?.dailyGoal ?? 5;
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final isDone = current >= target;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? Colors.green.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDone
                        ? [Colors.green, Colors.lightGreen]
                        : [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary
                          ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isDone
                          ? Colors.green.withValues(alpha: 0.3)
                          : theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  isDone ? Icons.check_circle : Icons.track_changes,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              if (isDone)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Text('COMPLETED',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('$current/$target',
              style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text('Daily Goal',
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
          Text(isDone ? 'Goal achieved! 🎉' : 'Keep going!',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: isDone
                      ? Colors.green
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              color: isDone ? Colors.green : theme.colorScheme.primary,
              minHeight: 10,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildMissionCard(bool isCompleted, ThemeData theme) {
    // Handle case where daily mission is null
    if (_dailyMission == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Mission Available',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Create some study content first to generate your daily mission.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/create'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Study Content'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withValues(alpha: 0.1)
                      : theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.rocket_launch_rounded,
                  color: isCompleted ? Colors.green : theme.colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompleted ? 'Mission Accomplished!' : "Today's Mission",
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (!isCompleted)
                      Text('Boost your momentum now',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6))),
                  ],
                ),
              ),
              if (isCompleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Text('COMPLETED',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isCompleted) ...[
            // Mission metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMissionMetric(Icons.timelapse,
                    "${_dailyMission!.estimatedTimeMinutes}m", theme),
                _buildMissionMetric(Icons.style,
                    "${_dailyMission!.flashcardIds.length} cards", theme),
                _buildMissionMetric(Icons.speed,
                    "+${_dailyMission!.momentumReward} pts", theme),
              ],
            ),
            const SizedBox(height: 24),
            // Start mission button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _startMission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white),
                    const SizedBox(width: 12),
                    Text('Start Mission',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onPrimary)),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Completion message
            Text(
              "You've earned +${_dailyMission!.momentumReward} momentum score today!",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 16),
            // Growth CTA when finished
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text('Ready for more?',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  Text('Generate a new quiz to strengthen your knowledge.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/create'),
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text('Create New Content'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1);
  }

  Widget _buildMissionMetric(IconData icon, String label, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF5C6BC0)),
        const SizedBox(height: 4),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
      ],
    );
  }

  Widget _buildRecentActivity(UserModel? user, ThemeData theme) {
    if (user == null) return const SizedBox();
    final localDb = Provider.of<LocalDatabaseService>(context, listen: false);

    return StreamBuilder(
      stream: Rx.combineLatest3(
        localDb.watchAllFlashcardSets(user.uid),
        localDb.watchAllQuizzes(user.uid),
        localDb.watchAllSummaries(user.uid),
        (sets, quizzes, summaries) {
          // Filter out any null items and combine
          final all = <dynamic>[
            ...sets.where((s) => s != null),
            ...quizzes.where((q) => q != null),
            ...summaries.where((s) => s != null),
          ];

          // Safe sort with null checks to prevent null errors
          all.sort((a, b) {
            if (a == null || b == null) return 0;
            final aTime = a.timestamp;
            final bTime = b.timestamp;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          return all.take(5).toList();
        },
      ).shareReplay(maxSize: 1), // Allow multiple subscribers with cached value
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data as List<dynamic>;

        if (items.isEmpty) {
          return Center(
              child: Text('No recent activity',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6))));
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            String title = item.title;
            IconData icon = Icons.article_rounded;
            Color color = Colors.blue;
            String type = 'Summary';

            if (item is LocalFlashcardSet) {
              icon = Icons.style_rounded;
              color = Colors.orange;
              type = 'Flashcards';
            } else if (item is LocalQuiz) {
              icon = Icons.quiz_rounded;
              color = Colors.teal;
              type = 'Quiz';
            }

            return Container(
              width: 150,
              margin: const EdgeInsets.only(right: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.5)),
                    ),
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
                                  builder: (_) =>
                                      SummaryScreen(summary: item)));
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const Spacer(),
                          Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 4),
                          Text(type,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6))),
                        ],
                      ),
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

  Widget _buildSrsBanner(ThemeData theme) {
    if (_dueCount == 0) {
      if (_nextReviewDate == null) return const SizedBox.shrink();

      // Show "Next Review" info
      final now = DateTime.now();
      final diff = _nextReviewDate!.difference(now);
      String timeText;
      if (diff.inHours > 0) {
        timeText = "in ${diff.inHours}h ${diff.inMinutes % 60}m";
      } else if (diff.inMinutes > 0) {
        timeText = "in ${diff.inMinutes}m";
      } else {
        timeText = "any moment now";
      }

      return _buildGlassCard(
        theme: theme,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.timer_outlined,
                  color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All Caught Up! ✓',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                  Text('Next review session $timeText',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SpacedRepetitionScreen(),
          ),
        );
        _loadSrsStats(); // Refresh count on return
      },
      child: _buildGlassCard(
        theme: theme,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        borderColor: Colors.amber.withValues(alpha: 0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle),
              child: const Icon(Icons.notifications_active_rounded,
                  color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_dueCount Quick Reviews Due',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                  Text('Keep your streak alive!',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: theme.disabledColor, size: 16),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Future<void> _pickAndExtractFile(List<String> extensions) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        await _processExtraction(
          extensions.contains('pdf') ? 'pdf' : 'audio',
          file.bytes!,
        );
      }
    } catch (e) {
      _showError('Extraction failed: $e');
    }
  }

  Future<void> _pickAndExtractImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _processExtraction('image', bytes);
      }
    } catch (e) {
      _showError('Image extraction failed: $e');
    }
  }

  void _showPasteTextDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste Text'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Paste educational content here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(context);
              if (text.isNotEmpty) {
                _processExtraction('text', text);
              }
            },
            child: const Text('Extract'),
          ),
        ],
      ),
    );
  }

  void _showLinkDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analyze Link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste YouTube or Web URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              Navigator.pop(context);
              if (url.isNotEmpty) {
                _processExtraction('link', url);
              }
            },
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }

  Future<void> _processExtraction(String type, dynamic input) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    if (userId == null) return;

    final extractionService = Provider.of<ContentExtractionService>(context, listen: false);
    final progressNotifier = ValueNotifier<String>('Initializing extraction...');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExtractionProgressDialog(messageNotifier: progressNotifier),
    );

    try {
      final result = await extractionService.extractContent(
        type: type,
        input: input,
        userId: userId,
        onProgress: (m) => progressNotifier.value = m,
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        context.push('/create/extraction-view', extra: result);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError('Extraction failed: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
