import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:rxdart/rxdart.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);

    // Premium background gradient
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              WebColors.background,
              WebColors.primaryLight.withOpacity(0.5),
            ],
          ),
        ),
        child: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child:
                  user == null ? _buildLoginPrompt() : _buildMainContent(user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_person, size: 60, color: WebColors.textSecondary),
          const SizedBox(height: 20),
          Text(
            "Please Log In to View Library",
            style: TextStyle(
              color: WebColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/auth'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WebColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [WebColors.primary, const Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.library_books,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Library',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Text(
            'MENU',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WebColors.textTertiary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildSidebarTab(0, 'Folders', Icons.folder_open),
          const SizedBox(height: 8),
          _buildSidebarTab(1, 'All Content', Icons.dashboard_outlined),
          const SizedBox(height: 32),
          Text(
            'FILTERS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WebColors.textTertiary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildSidebarTab(2, 'Summaries', Icons.article_outlined),
          const SizedBox(height: 8),
          _buildSidebarTab(3, 'Quizzes', Icons.quiz_outlined),
          const SizedBox(height: 8),
          _buildSidebarTab(4, 'Flashcards', Icons.style_outlined),
          const Spacer(),
          _buildStorageUsed(),
        ],
      ),
    );
  }

  Widget _buildStorageUsed() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_queue, size: 20, color: WebColors.primary),
              const SizedBox(width: 8),
              Text(
                'Storage Used',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WebColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: 0.4, // Mock value
            backgroundColor: Colors.grey[200],
            color: WebColors.primary,
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Text(
            '45% of 1GB used',
            style: TextStyle(
              fontSize: 12,
              color: WebColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTab(int index, String title, IconData icon) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.animateTo(index)),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? WebColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : WebColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : WebColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(UserModel user) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildFolderGrid(user.uid),
                _buildCombinedGrid(user.uid),
                _buildLibraryGrid(user.uid, 'summaries', _summariesStream),
                _buildQuizGrid(user.uid),
                _buildLibraryGrid(user.uid, 'flashcards', _flashcardsStream),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: WebColors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search summaries, quizzes, flashcards...',
                hintStyle: TextStyle(color: WebColors.textTertiary),
                prefixIcon: Icon(Icons.search, color: WebColors.primary),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [WebColors.primary, const Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: WebColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => context.push('/create'),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Create New',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2);
  }

  // --- Grid Builders ---

  Widget _buildFolderGrid(String userId) {
    return FutureBuilder<List<Folder>>(
      future: _localDb.getAllFolders(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoading();
        final folders = snapshot.data ?? [];
        if (folders.isEmpty)
          return _buildEmptyState(
              'No folders yet', 'Organize your study materials into folders');

        return _buildMasonryGrid(
          folders
              .map((f) => _LibraryCardData(
                    title: f.name,
                    subtitle: '${f.itemCount} items',
                    icon: Icons.folder_rounded,
                    color: WebColors.accentOrange,
                    onTap: () => context.push('/library/results-view/${f.id}'),
                    isFolder: true,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildCombinedGrid(String userId) {
    return StreamBuilder<List<LibraryItem>>(
      stream: _allItemsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoading();
        final items = snapshot.data ?? [];
        final filtered = items
            .where((i) => i.title.toLowerCase().contains(_searchQuery))
            .toList();

        if (filtered.isEmpty) {
          if (_searchQuery.isNotEmpty)
            return _buildEmptyState(
                'No results found', 'Try adjusting your search query');
          return _buildEmptyState('Your library is empty',
              'Start creating content to populate your library');
        }

        return _buildContentGrid(filtered, userId);
      },
    );
  }

  Widget _buildLibraryGrid(
      String userId, String type, Stream<List<LibraryItem>>? stream) {
    return StreamBuilder<List<LibraryItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoading();
        final items = snapshot.data ?? [];
        if (items.isEmpty)
          return _buildEmptyState(
              'No ${type} yet', 'Create your first ${type} now');
        return _buildContentGrid(items, userId);
      },
    );
  }

  Widget _buildQuizGrid(String userId) {
    return Consumer<QuizViewModel>(
      builder: (context, vm, _) {
        final items = vm.quizzes
            .map((q) => LibraryItem(
                id: q.id,
                title: q.title,
                type: LibraryItemType.quiz,
                timestamp: Timestamp.fromDate(q.timestamp)))
            .toList();
        if (items.isEmpty)
          return _buildEmptyState(
              'No quizzes yet', 'Generate a quiz from any content');
        return _buildContentGrid(items, userId);
      },
    );
  }

  Widget _buildLoading() {
    return Center(child: CircularProgressIndicator(color: WebColors.primary));
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/web/empty_library.png',
            width: 200,
            height: 200,
          ).animate().scale(duration: 400.ms),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: WebColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 16, color: WebColors.textSecondary),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => context.push('/create'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              side: BorderSide(color: WebColors.primary),
            ),
            child:
                Text('Create New', style: TextStyle(color: WebColors.primary)),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms),
    );
  }

  Widget _buildContentGrid(List<LibraryItem> items, String userId) {
    final cardData = items.map((item) {
      IconData icon;
      Color color;
      String typeName;
      switch (item.type) {
        case LibraryItemType.summary:
          icon = Icons.article_rounded;
          color = WebColors.primary;
          typeName = 'Summary';
          break;
        case LibraryItemType.quiz:
          icon = Icons.quiz_rounded;
          color = WebColors.secondary;
          typeName = 'Quiz';
          break;
        case LibraryItemType.flashcards:
          icon = Icons.style_rounded;
          color = WebColors.accentPink;
          typeName = 'Flashcards';
          break;
      }

      return _LibraryCardData(
        title: item.title,
        subtitle: typeName,
        icon: icon,
        color: color,
        onTap: () {
          if (item.type == LibraryItemType.summary) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SummaryScreen(summary: null)));
          }
        },
      );
    }).toList();

    return _buildMasonryGrid(cardData);
  }

  Widget _buildMasonryGrid(List<_LibraryCardData> cards) {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.4,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return _buildLibraryCard(card: card, delay: index * 50);
      },
    );
  }

  Widget _buildLibraryCard({
    required _LibraryCardData card,
    required int delay,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: card.onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
            // Gradient border effect could be added here
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
                      color: card.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(card.icon, color: card.color, size: 28),
                  ),
                  if (card.isFolder)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'FOLDER',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500]),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                card.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: WebColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: WebColors.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    'Just now', // Placeholder for real time
                    style: TextStyle(
                      fontSize: 13,
                      color: WebColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    card.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: card.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideY(begin: 0.1, end: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class _LibraryCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isFolder;

  _LibraryCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isFolder = false,
  });
}
