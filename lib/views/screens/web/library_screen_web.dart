import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(right: BorderSide(color: WebColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: WebColors.HeroGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: WebColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Text(
                'SumQuiz',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 56),
          _buildSidebarLabel('MENU'),
          const SizedBox(height: 16),
          _buildSidebarTab(0, 'Folders', Icons.folder_rounded),
          const SizedBox(height: 8),
          _buildSidebarTab(1, 'All Content', Icons.grid_view_rounded),
          const SizedBox(height: 40),
          _buildSidebarLabel('FILTERS'),
          const SizedBox(height: 16),
          _buildSidebarTab(2, 'Summaries', Icons.description_rounded),
          const SizedBox(height: 8),
          _buildSidebarTab(3, 'Quizzes', Icons.quiz_rounded),
          const SizedBox(height: 8),
          _buildSidebarTab(4, 'Flashcards', Icons.style_rounded),
          const Spacer(),
          _buildStorageUsed(),
          const SizedBox(height: 24),
          _buildPremiumCTA(),
        ],
      ),
    );
  }

  Widget _buildSidebarLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: WebColors.textTertiary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPremiumCTA() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: WebColors.HeroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: WebColors.primary.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Go Pro',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Unlock all features',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/subscription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: WebColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Upgrade Now'),
            ),
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.subtleShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: WebColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText:
                    'Search through your summaries, quizzes, and flashcards...',
                hintStyle: GoogleFonts.outfit(color: WebColors.textTertiary),
                prefixIcon: Icon(Icons.search_rounded,
                    color: WebColors.primary, size: 24),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: WebColors.HeroGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: WebColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/create'),
              icon:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: Text(
                'Create New',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  // --- Grid Builders ---

  Widget _buildFolderGrid(String userId) {
    return FutureBuilder<List<Folder>>(
      future: _localDb.getAllFolders(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoading();
        final folders = snapshot.data ?? [];
        if (folders.isEmpty) {
          return _buildEmptyState(
              'No folders yet', 'Organize your study materials into folders');
        }

        return _buildMasonryGrid(
          folders
              .map((f) => _LibraryCardData(
                    title: f.name,
                    subtitle: 'View items',
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
          if (_searchQuery.isNotEmpty) {
            return _buildEmptyState(
                'No results found', 'Try adjusting your search query');
          }
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
        if (items.isEmpty) {
          return _buildEmptyState(
              'No $type yet', 'Create your first $type now');
        }
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
        if (items.isEmpty) {
          return _buildEmptyState(
              'No quizzes yet', 'Generate a quiz from any content');
        }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 900) crossAxisCount = 2;
        if (constraints.maxWidth < 600) crossAxisCount = 1;

        return GridView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 32,
            mainAxisSpacing: 32,
            childAspectRatio: 1.3,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return _buildLibraryCard(card: card, delay: index * 40);
          },
        );
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: WebColors.border),
            boxShadow: WebColors.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
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
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(card.icon, color: card.color, size: 24),
                          ),
                          if (card.isFolder)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: WebColors.backgroundAlt,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'FOLDER',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: WebColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          IconButton(
                            onPressed: () {}, // Future action menu
                            icon: Icon(Icons.more_vert_rounded,
                                color: WebColors.textTertiary, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        card.title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: WebColors.textPrimary,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            height: 6,
                            width: 6,
                            decoration: BoxDecoration(
                              color: card.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            card.subtitle,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: WebColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.schedule_rounded,
                              size: 14, color: WebColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            'Just now',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: WebColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Subtle hover overlay effect
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: card.onTap,
                      hoverColor: card.color.withOpacity(0.02),
                      splashColor: card.color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
          duration: 400.ms,
        );
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
