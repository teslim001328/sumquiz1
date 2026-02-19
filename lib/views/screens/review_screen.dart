import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

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
import '../../services/spaced_repetition_service.dart';
import 'package:rxdart/rxdart.dart';
import 'exam_creation_screen.dart';
import '../../services/content_extraction_service.dart';
import '../widgets/extraction_progress_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/upgrade_dialog.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  DailyMission? _dailyMission;
  bool _isLoading = true;
  String? _error;
  double _masteryScore = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
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
      final mastery = srsService.getMasteryScore(userId);

      if (mounted) {
        setState(() {
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

  bool _checkProAccess(String feature) {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user != null && !user.isPro) {
      showDialog(
        context: context,
        builder: (_) => UpgradeDialog(featureName: feature),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Dashboard',
            style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A))),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: isDark ? Colors.white70 : const Color(0xFF475569)),
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
            onTap: () {
              if (_checkProAccess('Tutor/Teacher Exam')) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExamCreationScreen()),
                );
              }
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.picture_as_pdf),
            label: 'Upload Doc',
            onTap: () {
              if (_checkProAccess('Document Upload')) {
                _pickAndExtractFile(['pdf', 'doc', 'docx', 'ppt', 'pptx']);
              }
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.link),
            label: 'Analyze Link',
            onTap: () {
              if (_checkProAccess('Analyze Link')) {
                _showLinkDialog();
              }
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.camera_alt),
            label: 'Image/Snap',
            onTap: () {
              if (_checkProAccess('Image Scan')) {
                _pickAndExtractImage(ImageSource.camera);
              }
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.audiotrack),
            label: 'Audio',
            onTap: () {
              if (_checkProAccess('Audio Upload')) {
                _pickAndExtractFile(['mp3', 'wav', 'm4a']);
              }
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.text_fields),
            label: 'Paste Text',
            onTap: _showPasteTextDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: theme.textTheme.bodyMedium))
              : _buildDashboardContent(user, theme),
    );
  }

  Widget _buildDashboardContent(UserModel? user, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${user?.displayName ?? 'Learner'}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 24),
          _buildMasteryCard(theme),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildMomentumCard(user, theme)),
              const SizedBox(width: 16),
              Expanded(child: _buildDailyGoalCard(user, theme)),
            ],
          ),
          const SizedBox(height: 24),
          _buildMissionCard(theme),
          const SizedBox(height: 32),
          Text(
            'Jump Back In',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 16),
          _buildRecentActivity(user, theme),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
      {required Widget child, Color? color, required ThemeData theme}) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildMasteryCard(ThemeData theme) {
    return _buildDashboardCard(
      theme: theme,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star_rounded,
                color: theme.colorScheme.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mastery Level',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodySmall?.color?.withAlpha(178),
                  ),
                ),
                Text(
                  '${_masteryScore.toStringAsFixed(0)}% Overall Progress',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push('/progress'),
            child: const Text('Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildMomentumCard(UserModel? user, ThemeData theme) {
    return _buildDashboardCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: Colors.orange, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            (user?.currentMomentum ?? 0).toString(),
            style:
                theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Momentum',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withAlpha(178),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyGoalCard(UserModel? user, ThemeData theme) {
    final current = user?.itemsCompletedToday ?? 0;
    final target = user?.dailyGoal ?? 20;
    final percent = target > 0 ? (current / target) : 0.0;

    return _buildDashboardCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircularPercentIndicator(
                radius: 22.0,
                lineWidth: 5.0,
                percent: percent,
                center: Text(
                  '${(percent * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.0),
                ),
                progressColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.primary.withAlpha(51),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$current/$target items',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          Text(
            'Daily Goal',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withAlpha(178),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard(ThemeData theme) {
    final isCompleted = _dailyMission?.isCompleted ?? false;

    return _buildDashboardCard(
      theme: theme,
      color: theme.colorScheme.primary.withAlpha(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.rocket_launch_rounded,
                    color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                "Today's Mission",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Boost your momentum now',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withAlpha(178),
            ),
          ),
          const SizedBox(height: 20),
          if (!isCompleted)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMissionMetric(Icons.timelapse,
                    "${_dailyMission!.estimatedTimeMinutes}m", theme),
                _buildMissionMetric(Icons.style,
                    "${_dailyMission!.flashcardIds.length} cards", theme),
                _buildMissionMetric(Icons.military_tech_rounded,
                    "+${_dailyMission!.momentumReward} pts", theme),
              ],
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startMission,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Start Mission'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionMetric(IconData icon, String label, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary.withAlpha(204)),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
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
          final all = <dynamic>[...sets, ...quizzes, ...summaries];
          all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return all.take(5).toList();
        },
      ).shareReplay(maxSize: 1),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No recent activity',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          );
        }
        final items = snapshot.data!;

        return SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              String title = item.title;
              IconData icon = Icons.article_rounded;
              Color color = Colors.blue;

              if (item is LocalFlashcardSet) {
                icon = Icons.style_rounded;
                color = Colors.orange;
              } else if (item is LocalQuiz) {
                icon = Icons.quiz_rounded;
                color = Colors.teal;
              }

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 16),
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
                  child: _buildDashboardCard(
                    theme: theme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: color.withAlpha(26),
                              shape: BoxShape.circle),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const Spacer(),
                        Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Methods for FAB actions
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

    final extractionService =
        Provider.of<ContentExtractionService>(context, listen: false);
    final progressNotifier = ValueNotifier<String>('Initializing extraction...');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          ExtractionProgressDialog(messageNotifier: progressNotifier),
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
