import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';

import '../../models/user_model.dart';
import '../../models/library_item.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';
import '../../view_models/quiz_view_model.dart';
import '../../models/editable_content.dart';
import '../../models/summary_model.dart';
import '../../models/quiz_model.dart';
import '../../models/flashcard_set.dart';
import '../../models/folder.dart';

import '../screens/summary_screen.dart';
import '../screens/quiz_screen.dart';
import '../screens/flashcards_screen.dart';
import '../../models/local_summary.dart';
import '../../models/quiz_question.dart';
import '../../models/flashcard.dart';
import '../../models/local_quiz.dart';
import '../../models/local_quiz_question.dart';
import '../../models/local_flashcard_set.dart';
import '../../models/local_flashcard.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  LibraryScreenState createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final TextEditingController _searchController = TextEditingController();

  bool _isOfflineMode = false;
  String _searchQuery = '';

  Stream<List<LibraryItem>>? _allItemsStream;
  Stream<List<LibraryItem>>? _summariesStream;
  Stream<List<LibraryItem>>? _flashcardsStream;
  String? _userIdForStreams;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _localDb.init();
    _loadOfflineModePreference();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<UserModel?>(context);
    if (user != null && user.uid != _userIdForStreams) {
      _userIdForStreams = user.uid;
      _initializeStreams(user.uid);
      if (mounted) {
        Provider.of<QuizViewModel>(context, listen: false)
            .initializeForUser(user.uid);
      }
    } else if (user == null && _userIdForStreams != null) {
      _clearStreams();
    }
  }

  void _initializeStreams(String userId) {
    // Summaries: Merge Firestore & Local
    final localSummaries = _localDb.watchAllSummaries(userId).map((list) => list
        .map((s) => LibraryItem(
            id: s.id,
            title: s.title,
            type: LibraryItemType.summary,
            timestamp: Timestamp.fromDate(s.timestamp),
            isReadOnly: s.isReadOnly))
        .toList());

    final firestoreSummaries =
        _firestoreService.streamItems(userId, 'summaries');

    _summariesStream = Rx.combineLatest2<List<LibraryItem>, List<LibraryItem>,
        List<LibraryItem>>(
      localSummaries,
      firestoreSummaries.handleError(
          (_) => <LibraryItem>[]), // Handle offline/error gracefully
      (local, cloud) {
        final ids = local.map((e) => e.id).toSet();
        return [...local, ...cloud.where((c) => !ids.contains(c.id))];
      },
    ).asBroadcastStream();

    // Flashcards: Merge Firestore & Local
    final localFlashcards = _localDb.watchAllFlashcardSets(userId).map((list) =>
        list
            .map((f) => LibraryItem(
                id: f.id,
                title: f.title,
                type: LibraryItemType.flashcards,
                timestamp: Timestamp.fromDate(f.timestamp),
                isReadOnly: f.isReadOnly))
            .toList());

    final firestoreFlashcards =
        _firestoreService.streamItems(userId, 'flashcards');

    _flashcardsStream = Rx.combineLatest2<List<LibraryItem>, List<LibraryItem>,
        List<LibraryItem>>(
      localFlashcards,
      firestoreFlashcards.handleError((_) => <LibraryItem>[]),
      (local, cloud) {
        final ids = local.map((e) => e.id).toSet();
        return [...local, ...cloud.where((c) => !ids.contains(c.id))];
      },
    ).asBroadcastStream();

    // Quizzes: Merge Firestore & Local
    final localQuizzes = _localDb.watchAllQuizzes(userId).map((list) => list
        .map((q) => LibraryItem(
            id: q.id,
            title: q.title,
            type: LibraryItemType.quiz,
            timestamp: Timestamp.fromDate(q.timestamp),
            isReadOnly: q.isReadOnly))
        .toList());

    // All Items
    _allItemsStream = Rx.combineLatest3<List<LibraryItem>, List<LibraryItem>,
            List<LibraryItem>, List<LibraryItem>>(
        _summariesStream!, _flashcardsStream!, localQuizzes,
        (summaries, flashcards, quizzes) {
      final all = [...summaries, ...flashcards, ...quizzes];
      all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return all;
    }).asBroadcastStream();
  }

  void _clearStreams() {
    setState(() {
      _userIdForStreams = null;
      _allItemsStream = null;
      _summariesStream = null;
      _flashcardsStream = null;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() =>
      setState(() => _searchQuery = _searchController.text.toLowerCase());

  Future<void> _loadOfflineModePreference() async {
    final isOffline = await _localDb.isOfflineModeEnabled();
    if (mounted) setState(() => _isOfflineMode = isOffline);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, theme),
      body: Stack(
        children: [
          // Animated Background
          Animate(
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: [
              CustomEffect(
                duration: 10.seconds,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                theme.colorScheme.surface,
                                Color.lerp(theme.colorScheme.surface,
                                    theme.colorScheme.primaryContainer, value)!,
                              ]
                            : [
                                const Color(0xFFE3F2FD),
                                Color.lerp(const Color(0xFFE3F2FD),
                                    const Color(0xFFBBDEFB), value)!,
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
            child: user == null
                ? _buildLoggedOutView(theme)
                : _buildLibraryContent(user, theme),
          ),
        ],
      ),
      floatingActionButton: user != null && !_isOfflineMode
          ? FloatingActionButton(
              onPressed: () => _showCreateOptions(context, theme),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.add),
            ).animate().scale(delay: 500.ms)
          : null,
    );
  }

  AppBar _buildAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text('Library',
          style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
      centerTitle: true,
      actions: [
        IconButton(
            icon:
                Icon(Icons.keyboard_outlined, color: theme.colorScheme.primary),
            tooltip: 'Enter Code',
            onPressed: () => _showJoinCodeDialog(context)),
        IconButton(
            icon:
                Icon(Icons.settings_outlined, color: theme.colorScheme.primary),
            onPressed: () {
              if (mounted) {
                context.push('/settings');
              }
            }),
      ],
    );
  }

  Widget _buildLoggedOutView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: _buildGlassContainer(
          theme: theme,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text('Please Log In',
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary)),
              const SizedBox(height: 12),
              Text(
                'Log in to access your synchronized library across all your devices.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: _buildGlassContainer(
          theme: theme,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.signal_wifi_off_outlined,
                  size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text('Offline Mode',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'You are currently in offline mode. Only locally stored content is available.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryContent(UserModel user, ThemeData theme) {
    if (_isOfflineMode) {
      return _buildOfflineState(theme);
    }
    return Column(
      children: [
        _buildSearchAndTabs(theme),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFolderList(user.uid, theme),
              _buildCombinedList(user.uid, theme),
              _buildLibraryList(user.uid, 'summaries', _summariesStream, theme),
              _buildQuizList(user.uid, theme),
              _buildLibraryList(
                  user.uid, 'flashcards', _flashcardsStream, theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndTabs(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search Library...',
                hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
              ),
            ),
          ).animate().fadeIn().slideY(begin: -0.2),
          const SizedBox(height: 16),
          _buildTabBar(theme),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabs: const [
        Tab(text: 'Folders'),
        Tab(text: 'All'),
        Tab(text: 'Summaries'),
        Tab(text: 'Quizzes'),
        Tab(text: 'Flashcards'),
      ],
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: theme.colorScheme.primary,
      ),
      labelStyle:
          theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
      unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      labelColor: theme.colorScheme.onPrimary,
      dividerColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          return states.contains(WidgetState.focused)
              ? null
              : Colors.transparent;
        },
      ),
    ).animate().fadeIn(delay: 100.ms).slideX();
  }

  Widget _buildFolderList(String userId, ThemeData theme) {
    return FutureBuilder<List<Folder>>(
      future: _localDb.getAllFolders(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final folders = snapshot.data ?? [];
        if (folders.isEmpty) {
          return _buildNoContentState('folders', theme);
        }

        folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            final folder = folders[index];
            return _buildGlassListTile(
              title: folder.name,
              subtitle: 'Created: ${folder.createdAt.toString().split(' ')[0]}',
              icon: Icons.folder,
              iconColor: Colors.amber,
              theme: theme,
              onTap: () {
                context.push('/library/results-view/${folder.id}');
              },
            )
                .animate()
                .fadeIn(delay: (50 * index).ms)
                .slideY(begin: 0.1, duration: 300.ms);
          },
        );
      },
    );
  }

  Widget _buildCombinedList(String userId, ThemeData theme) {
    return StreamBuilder<List<LibraryItem>>(
      stream: _allItemsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allItems = snapshot.data ?? [];

        if (allItems.isEmpty) {
          return _buildNoContentState('all', theme);
        }
        return _buildContentList(allItems, userId, theme);
      },
    );
  }

  Widget _buildQuizList(String userId, ThemeData theme) {
    return Consumer<QuizViewModel>(
      builder: (context, quizViewModel, child) {
        if (quizViewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (quizViewModel.quizzes.isEmpty) {
          return _buildNoContentState('quizzes', theme);
        }

        final quizItems = quizViewModel.quizzes
            .map((quiz) => LibraryItem(
                id: quiz.id,
                title: quiz.title,
                type: LibraryItemType.quiz,
                timestamp: Timestamp.fromDate(quiz.timestamp),
                isReadOnly: quiz.isReadOnly))
            .toList();

        return _buildContentList(quizItems, userId, theme);
      },
    );
  }

  Widget _buildLibraryList(String userId, String type,
      Stream<List<LibraryItem>>? stream, ThemeData theme) {
    return StreamBuilder<List<LibraryItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return _buildNoContentState(type, theme);
        }
        return _buildContentList(snapshot.data!, userId, theme);
      },
    );
  }

  Widget _buildContentList(
      List<LibraryItem> items, String userId, ThemeData theme) {
    final filteredItems = items
        .where((item) => item.title.toLowerCase().contains(_searchQuery))
        .toList();

    if (filteredItems.isEmpty) {
      if (items.isNotEmpty && _searchQuery.isNotEmpty) {
        return _buildNoSearchResultsState(theme);
      }
      return _buildNoContentState(
          _tabController.index == 0
              ? 'all'
              : [
                  'summaries',
                  'quizzes',
                  'flashcards'
                ][_tabController.index - 1],
          theme);
    }

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 80.0),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) =>
              _buildLibraryCard(filteredItems[index], userId, theme)
                  .animate()
                  .fadeIn(delay: (50 * index).ms)
                  .slideY(begin: 0.1, duration: 300.ms),
        );
      } else {
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 80.0),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400.0,
            childAspectRatio: 3.5,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) =>
              _buildLibraryCard(filteredItems[index], userId, theme)
                  .animate()
                  .fadeIn(delay: (50 * index).ms)
                  .scale(duration: 300.ms),
        );
      }
    });
  }

  Widget _buildLibraryCard(LibraryItem item, String userId, ThemeData theme) {
    IconData icon;
    Color iconColor;
    switch (item.type) {
      case LibraryItemType.summary:
        icon = Icons.article_outlined;
        iconColor = Colors.blueAccent;
        break;
      case LibraryItemType.quiz:
        icon = Icons.quiz_outlined;
        iconColor = Colors.greenAccent;
        break;
      case LibraryItemType.flashcards:
        icon = Icons.style_outlined;
        iconColor = Colors.orangeAccent;
        break;
    }

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: theme.dialogBackgroundColor,
              title: Text("Confirm Delete", style: theme.textTheme.titleLarge),
              content: Text("Are you sure you want to delete this item?",
                  style: theme.textTheme.bodyMedium),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Delete",
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        _deleteContent(userId, item);
      },
      child: _buildGlassListTile(
        title: item.title,
        subtitle: item.type.toString().split('.').last.toUpperCase(),
        icon: icon,
        iconColor: iconColor,
        theme: theme,
        onTap: () => _navigateToContent(userId, item),
        trailing: IconButton(
          icon: Icon(Icons.more_horiz,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          onPressed: () => _showItemMenu(userId, item),
        ),
      ),
    );
  }

  Widget _buildGlassListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required ThemeData theme,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: theme.cardColor.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  Icon(Icons.chevron_right,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoContentState(String type, ThemeData theme) {
    final typeName = type == 'all' ? 'content' : type.replaceAll('s', '');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined,
                size: 100,
                color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            const SizedBox(height: 24),
            Text('No $typeName yet',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 12),
            Text(
              'Tap the + button to create your first set of study materials!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildNoSearchResultsState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_outlined,
                size: 100,
                color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            const SizedBox(height: 24),
            Text('No Results Found',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 12),
            Text(
              'Your search for "$_searchQuery" did not match any content. Try a different search term.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  void _showCreateOptions(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Wrap(
          runSpacing: 16,
          children: [
            Text("Create New",
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface)),
            _buildCreationOption(
              icon: Icons.article_outlined,
              title: "Create Summary",
              subtitle: "Summarize text or PDFs",
              color: Colors.blueAccent,
              theme: theme,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SummaryScreen()));
              },
            ),
            _buildCreationOption(
              icon: Icons.quiz_outlined,
              title: "Create Quiz",
              subtitle: "Generate a quiz from any topic",
              color: Colors.greenAccent,
              theme: theme,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const QuizScreen()));
              },
            ),
            _buildCreationOption(
              icon: Icons.style_outlined,
              title: "Create Flashcards",
              subtitle: "Make flashcards for study",
              color: Colors.orangeAccent,
              theme: theme,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FlashcardsScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreationOption(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap,
      required ThemeData theme}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface)),
              Text(subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildGlassContainer(
      {required Widget child, required ThemeData theme}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: theme.cardColor.withValues(alpha: 0.9), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  void _showItemMenu(String userId, LibraryItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Wrap(
        children: [
          if (!item.isReadOnly)
            ListTile(
              leading: Icon(Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.onSurface),
              title: Text('Edit',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(ctx);
                _editContent(userId, item);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(ctx);
              _deleteContent(userId, item);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToContent(String userId, LibraryItem item) async {
    Widget? screen;
    switch (item.type) {
      case LibraryItemType.summary:
        // Try Local First
        final localSummary = await _localDb.getSummary(item.id);
        if (mounted && localSummary != null) {
          screen = SummaryScreen(summary: localSummary);
        } else if (!_isOfflineMode) {
          // Fallback to Firestore
          final content = await _firestoreService.getSpecificItem(userId, item);
          if (mounted && content != null) {
            final summary = content as Summary;
            screen = SummaryScreen(
                summary: LocalSummary(
                    id: summary.id,
                    title: summary.title,
                    content: summary.content,
                    tags: summary.tags,
                    timestamp: summary.timestamp.toDate(),
                    userId: userId,
                    isReadOnly: item
                        .isReadOnly // Should be false if from Firestore usually
                    ));
          }
        }
        break;
      case LibraryItemType.quiz:
        final localQuiz = await _localDb.getQuiz(item.id);
        if (!mounted) return;
        if (localQuiz != null) {
          screen = QuizScreen(quiz: localQuiz);
        }
        break;
      case LibraryItemType.flashcards:
        // Try Local First
        final localSet = await _localDb.getFlashcardSet(item.id);
        if (mounted && localSet != null) {
          screen = FlashcardsScreen(
              flashcardSet: FlashcardSet(
                // Map Local to Model because FlashcardsScreen expects Model?
                id: localSet.id,
                title: localSet.title,
                flashcards: localSet.flashcards
                    .map((f) =>
                        Flashcard(question: f.question, answer: f.answer))
                    .toList(),
                timestamp: Timestamp.fromDate(localSet.timestamp),
              ),
              isReadOnly: localSet.isReadOnly,
              publicDeckId: localSet.publicDeckId);
          // Note: FlashcardsScreen might need update to handle isReadOnly if it has edit buttons.
          // For now we just ensure navigation works.
        } else if (!_isOfflineMode) {
          final content = await _firestoreService.getSpecificItem(userId, item);
          if (mounted && content != null) {
            screen = FlashcardsScreen(
                flashcardSet: content as FlashcardSet,
                isReadOnly: item.isReadOnly);
          }
        }
        break;
    }

    if (!mounted) return;

    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not load content.')));
    }
  }

  Future<void> _editContent(String userId, LibraryItem item) async {
    EditableContent? editableContent;

    // Fetch from Local DB first
    switch (item.type) {
      case LibraryItemType.summary:
        var summary = await _localDb.getSummary(item.id);
        if (summary == null && !_isOfflineMode) {
          final cloudContent =
              await _firestoreService.getSpecificItem(userId, item);
          if (cloudContent is Summary) {
            summary = LocalSummary(
                id: cloudContent.id,
                userId: userId,
                title: cloudContent.title,
                content: cloudContent.content,
                tags: cloudContent.tags,
                timestamp: cloudContent.timestamp.toDate(),
                isSynced: true);
          }
        }

        if (summary != null) {
          editableContent = EditableContent.fromSummary(
              summary.id,
              summary.title,
              summary.content,
              summary.tags,
              Timestamp.fromDate(summary.timestamp));
        }
        break;
      case LibraryItemType.quiz:
        var quiz = await _localDb.getQuiz(item.id);
        if (quiz == null && !_isOfflineMode) {
          final cloudContent =
              await _firestoreService.getSpecificItem(userId, item);
          if (cloudContent is Quiz) {
            quiz = LocalQuiz(
                id: cloudContent.id,
                userId: userId,
                title: cloudContent.title,
                questions: cloudContent.questions
                    .map((q) => LocalQuizQuestion(
                        question: q.question,
                        options: q.options,
                        correctAnswer: q.correctAnswer))
                    .toList(),
                timestamp: cloudContent.timestamp.toDate(),
                isSynced: true);
          }
        }

        if (quiz != null) {
          editableContent = EditableContent.fromQuiz(
              quiz.id,
              quiz.title,
              quiz.questions
                  .map((q) => QuizQuestion(
                      question: q.question,
                      options: q.options,
                      correctAnswer: q.correctAnswer))
                  .toList(),
              Timestamp.fromDate(quiz.timestamp));
        }
        break;
      case LibraryItemType.flashcards:
        var flashcardSet = await _localDb.getFlashcardSet(item.id);
        if (flashcardSet == null && !_isOfflineMode) {
          final cloudContent =
              await _firestoreService.getSpecificItem(userId, item);
          if (cloudContent is FlashcardSet) {
            flashcardSet = LocalFlashcardSet(
                id: cloudContent.id,
                userId: userId,
                title: cloudContent.title,
                flashcards: cloudContent.flashcards
                    .map((f) =>
                        LocalFlashcard(question: f.question, answer: f.answer))
                    .toList(),
                timestamp: cloudContent.timestamp.toDate(),
                isSynced: true);
          }
        }

        if (flashcardSet != null) {
          editableContent = EditableContent.fromFlashcardSet(
              flashcardSet.id,
              flashcardSet.title,
              flashcardSet.flashcards
                  .map((f) => Flashcard(
                      id: const Uuid().v4(),
                      question: f.question,
                      answer: f.answer))
                  .toList(),
              Timestamp.fromDate(flashcardSet.timestamp));
        }
        break;
    }

    if (!mounted) return;

    if (editableContent != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Edit feature coming soon!")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not load for editing.')));
    }
  }

  Future<void> _deleteContent(String userId, LibraryItem item) async {
    try {
      if (!_isOfflineMode) {
        await _firestoreService.deleteItem(userId, item);
      }

      switch (item.type) {
        case LibraryItemType.summary:
          await _localDb.deleteSummary(item.id);
          break;
        case LibraryItemType.quiz:
          await _localDb.deleteQuiz(item.id);
          break;
        case LibraryItemType.flashcards:
          await _localDb.deleteFlashcardSet(item.id);
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error deleting item: $e')));
      }
    }
  }

  void _showJoinCodeDialog(BuildContext context) {
    final TextEditingController codeController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Join via Code'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Enter the 6-character code shared by your creator.'),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. AB1234',
                  ),
                  maxLength: 6,
                ),
                if (isLoading) const LinearProgressIndicator(),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final code = codeController.text.trim();
                        if (code.length < 4) return;

                        setState(() => isLoading = true);
                        try {
                          final firestoreService = FirestoreService();
                          final deck = await firestoreService
                              .fetchPublicDeckByCode(code);

                          if (!context.mounted) return;
                          Navigator.pop(context); // Close dialog

                          if (deck != null) {
                            context.push('/public_deck/${deck.id}',
                                extra: deck);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Deck not found.')));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')));
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                          }
                        }
                      },
                child: const Text('Join'),
              ),
            ],
          );
        });
      },
    );
  }
}
