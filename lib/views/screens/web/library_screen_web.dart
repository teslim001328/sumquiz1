import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/models/library_item.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/view_models/quiz_view_model.dart';
import 'package:sumquiz/views/screens/summary_screen.dart';
import 'package:sumquiz/models/folder.dart';

class LibraryScreenWeb extends StatefulWidget {
  const LibraryScreenWeb({super.key});

  @override
  LibraryScreenWebState createState() => LibraryScreenWebState();
}

class LibraryScreenWebState extends State<LibraryScreenWeb>
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
    }
  }

  void _initializeStreams(String userId) {
    // Reusing the stream logic from LibraryScreen for consistency
    final localSummaries = _localDb.watchAllSummaries(userId).map((list) => list
        .map((s) => LibraryItem(
            id: s.id,
            title: s.title,
            type: LibraryItemType.summary,
            timestamp: Timestamp.fromDate(s.timestamp)))
        .toList());

    final firestoreSummaries =
        _firestoreService.streamItems(userId, 'summaries');

    _summariesStream = Rx.combineLatest2<List<LibraryItem>, List<LibraryItem>,
        List<LibraryItem>>(
      localSummaries,
      firestoreSummaries.handleError((_) => <LibraryItem>[]),
      (local, cloud) {
        final ids = local.map((e) => e.id).toSet();
        return [...local, ...cloud.where((c) => !ids.contains(c.id))];
      },
    ).asBroadcastStream();

    final localFlashcards = _localDb.watchAllFlashcardSets(userId).map((list) =>
        list
            .map((f) => LibraryItem(
                id: f.id,
                title: f.title,
                type: LibraryItemType.flashcards,
                timestamp: Timestamp.fromDate(f.timestamp)))
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

    final localQuizzes = _localDb.watchAllQuizzes(userId).map((list) => list
        .map((q) => LibraryItem(
            id: q.id,
            title: q.title,
            type: LibraryItemType.quiz,
            timestamp: Timestamp.fromDate(q.timestamp)))
        .toList());

    _allItemsStream = Rx.combineLatest3<List<LibraryItem>, List<LibraryItem>,
            List<LibraryItem>, List<LibraryItem>>(
        _summariesStream!, _flashcardsStream!, localQuizzes,
        (summaries, flashcards, quizzes) {
      final all = [...summaries, ...flashcards, ...quizzes];
      all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return all;
    }).asBroadcastStream();
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

    // Desktop Layout: Sidebar + Main Content Area
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Sidebar (could be part of shell, but here we can customize filtering)
          _buildWebSidebar(theme),
          // Main Content
          Expanded(
            child: user == null
                ? const Center(child: Text("Please Log In"))
                : _buildWebMainContent(user, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSidebar(ThemeData theme) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text('Library',
              style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary)),
          const SizedBox(height: 32),
          _buildSidebarTab(0, 'Folders', Icons.folder_open, theme),
          _buildSidebarTab(1, 'All Content', Icons.dashboard_outlined, theme),
          _buildSidebarTab(2, 'Summaries', Icons.article_outlined, theme),
          _buildSidebarTab(3, 'Quizzes', Icons.quiz_outlined, theme),
          _buildSidebarTab(4, 'Flashcards', Icons.style_outlined, theme),
        ],
      ),
    );
  }

  Widget _buildSidebarTab(
      int index, String title, IconData icon, ThemeData theme) {
    final bool isSelected = _tabController.index == index;
    return InkWell(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          // Subtle background only when selected
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 22),
            const SizedBox(width: 16),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebMainContent(UserModel user, ThemeData theme) {
    return Column(
      children: [
        _buildWebHeader(theme),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics:
                const NeverScrollableScrollPhysics(), // Disable swipe on web
            children: [
              _buildFolderGrid(user.uid, theme),
              _buildCombinedGrid(user.uid, theme),
              _buildLibraryGrid(user.uid, 'summaries', _summariesStream, theme),
              _buildQuizGrid(user.uid, theme),
              _buildLibraryGrid(
                  user.uid, 'flashcards', _flashcardsStream, theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: TextField(
                controller: _searchController,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search your library...',
                  prefixIcon: Icon(Icons.search,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateOptions(context, theme),
            icon: Icon(Icons.add, color: theme.colorScheme.onPrimary),
            label: Text("Create New",
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimary)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderGrid(String userId, ThemeData theme) {
    return FutureBuilder<List<Folder>>(
      future: _localDb.getAllFolders(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final folders = snapshot.data ?? [];
        return GridView.builder(
          padding: const EdgeInsets.all(32),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            childAspectRatio: 1.2,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            final folder = folders[index];
            return _buildWebCard(
              title: folder.name,
              subtitle: 'Folder',
              icon: Icons.folder,
              color: Colors
                  .amber, // Keep amber as a distinct folder color, or theme.primary
              onTap: () => context.push('/library/results-view/${folder.id}'),
              theme: theme,
            );
          },
        );
      },
    );
  }

  Widget _buildCombinedGrid(String userId, ThemeData theme) {
    return StreamBuilder<List<LibraryItem>>(
      stream: _allItemsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        final filtered = items
            .where((i) => i.title.toLowerCase().contains(_searchQuery))
            .toList();
        return _buildContentGrid(filtered, userId, theme);
      },
    );
  }

  Widget _buildLibraryGrid(String userId, String type,
      Stream<List<LibraryItem>>? stream, ThemeData theme) {
    return StreamBuilder<List<LibraryItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildContentGrid(snapshot.data!, userId, theme);
      },
    );
  }

  Widget _buildQuizGrid(String userId, ThemeData theme) {
    return Consumer<QuizViewModel>(
      builder: (context, vm, _) {
        final items = vm.quizzes
            .map((q) => LibraryItem(
                id: q.id,
                title: q.title,
                type: LibraryItemType.quiz,
                timestamp: Timestamp.fromDate(q.timestamp)))
            .toList();
        return _buildContentGrid(items, userId, theme);
      },
    );
  }

  Widget _buildContentGrid(
      List<LibraryItem> items, String userId, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        childAspectRatio: 1.5,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        IconData icon;
        Color color;
        String typeName;
        switch (item.type) {
          case LibraryItemType.summary:
            icon = Icons.article;
            color = Colors.blue;
            typeName = 'Summary';
            break;
          case LibraryItemType.quiz:
            icon = Icons.quiz;
            color = Colors.green;
            typeName = 'Quiz';
            break;
          case LibraryItemType.flashcards:
            icon = Icons.style;
            color = Colors.orange;
            typeName = 'Flashcards';
            break;
        }

        return _buildWebCard(
          title: item.title,
          subtitle: typeName,
          icon: icon,
          color: color,
          onTap: () {
            // Navigation logic same as mobile
            if (item.type == LibraryItemType.summary) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SummaryScreen(summary: null)));
              // ideally fetch summary
            } else if (item.type == LibraryItemType.quiz) {
              // fetch quiz
            }
            // For now, placeholder or push with ID if route expects it
          },
          theme: theme,
        );
      },
    );
  }

  Widget _buildWebCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const Spacer(),
            Text(title,
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ).animate().scale(duration: 200.ms, curve: Curves.easeOut),
    );
  }

  void _showCreateOptions(BuildContext context, ThemeData theme) {
    // Show dialog instead of bottom sheet on web
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Create New Content",
                    style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface)),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.article, color: Colors.blue),
                  title: Text('Summary',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.onSurface)),
                  onTap: () => context.push('/create'),
                ),
                ListTile(
                  leading: const Icon(Icons.quiz, color: Colors.green),
                  title: Text('Quiz',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.onSurface)),
                  onTap: () => context.push('/create'),
                ),
                ListTile(
                  leading: const Icon(Icons.style, color: Colors.orange),
                  title: Text('Flashcards',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.onSurface)),
                  onTap: () => context.push('/create'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
