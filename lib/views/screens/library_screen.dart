import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_model.dart';
import '../../models/library_item.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';
import '../../view_models/quiz_view_model.dart';
import '../../models/editable_content.dart';
import '../../models/summary_model.dart';
import '../../models/quiz_model.dart';
import '../../models/flashcard_set.dart';
import '../../models/folder.dart'; // Added
import '../screens/edit_content_screen.dart';
import '../screens/summary_screen.dart';
import '../screens/quiz_screen.dart';
import '../screens/flashcards_screen.dart';
import '../../models/local_summary.dart';

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

  Stream<Map<String, List<LibraryItem>>>? _allItemsStream;
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
    setState(() {
      _allItemsStream =
          _firestoreService.streamAllItems(userId).asBroadcastStream();
      _summariesStream = _firestoreService
          .streamItems(userId, 'summaries')
          .asBroadcastStream();
      _flashcardsStream = _firestoreService
          .streamItems(userId, 'flashcards')
          .asBroadcastStream();
    });
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context, theme),
      body: user == null
          ? _buildLoggedOutView(theme)
          : _buildLibraryContent(user, theme),
      floatingActionButton: user != null && !_isOfflineMode
          ? FloatingActionButton(
              onPressed: () => _showCreateOptions(context),
              backgroundColor: theme.cardColor,
              foregroundColor: theme.iconTheme.color,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  AppBar _buildAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      title: Text('Library', style: theme.textTheme.headlineMedium),
      centerTitle: true,
      actions: [
        IconButton(
            icon: const Icon(Icons.settings_outlined),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 80, color: theme.iconTheme.color),
            const SizedBox(height: 24),
            Text('Please Log In', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              'Log in to access your synchronized library across all your devices.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.signal_wifi_off_outlined,
                size: 80, color: theme.iconTheme.color),
            const SizedBox(height: 24),
            Text('Offline Mode', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              'You are currently in offline mode. Only locally stored content is available.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
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
          TextField(
            controller: _searchController,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search Library...',
              hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
              prefixIcon:
                  Icon(Icons.search, color: theme.textTheme.bodySmall?.color),
              filled: true,
              fillColor: theme.cardColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none),
            ),
          ),
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
          color: theme.colorScheme.secondaryContainer),
      labelStyle: GoogleFonts.roboto(fontWeight: FontWeight.bold),
      unselectedLabelColor: theme.textTheme.bodySmall?.color,
      labelColor: theme.colorScheme.onSecondaryContainer,
      dividerColor: Colors.transparent,
    );
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
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading:
                    const Icon(Icons.folder, size: 40, color: Colors.amber),
                title: Text(folder.name, style: theme.textTheme.titleMedium),
                subtitle: Text(
                    'Created: ${folder.createdAt.toString().split(' ')[0]}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  context.push('/results-view/${folder.id}');
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCombinedList(String userId, ThemeData theme) {
    return Consumer<QuizViewModel>(
      builder: (context, quizViewModel, child) {
        return StreamBuilder<Map<String, List<LibraryItem>>>(
          stream: _allItemsStream,
          builder: (context, snapshot) {
            if (quizViewModel.isLoading ||
                (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)) {
              return const Center(child: CircularProgressIndicator());
            }

            final firestoreItems = snapshot.hasData
                ? snapshot.data!.values.expand((list) => list).toList()
                : <LibraryItem>[];
            final localQuizItems = quizViewModel.quizzes
                .map((quiz) => LibraryItem(
                    id: quiz.id,
                    title: quiz.title,
                    type: LibraryItemType.quiz,
                    timestamp: Timestamp.fromDate(quiz.timestamp)))
                .toList();

            final firestoreQuizIds = localQuizItems.map((q) => q.id).toSet();
            final filteredFirestoreItems = firestoreItems.where((item) =>
                item.type != LibraryItemType.quiz ||
                !firestoreQuizIds.contains(item.id));

            final allItems = [...filteredFirestoreItems, ...localQuizItems];
            allItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            if (allItems.isEmpty) {
              return _buildNoContentState('all', theme);
            }
            return _buildContentList(allItems, userId, theme);
          },
        );
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
                timestamp: Timestamp.fromDate(quiz.timestamp)))
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
              _buildLibraryCard(filteredItems[index], userId, theme),
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
              _buildLibraryCard(filteredItems[index], userId, theme),
        );
      }
    });
  }

  Widget _buildLibraryCard(LibraryItem item, String userId, ThemeData theme) {
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _navigateToContent(context, userId, item),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _getIconForType(item.type),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(item.type.toString().split('.').last,
                        style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_horiz, color: theme.iconTheme.color),
                onPressed: () => _showItemMenu(context, userId, item, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Icon _getIconForType(LibraryItemType type) {
    switch (type) {
      case LibraryItemType.summary:
        return const Icon(Icons.article_outlined, color: Colors.blueAccent);
      case LibraryItemType.quiz:
        return const Icon(Icons.quiz_outlined, color: Colors.greenAccent);
      case LibraryItemType.flashcards:
        return const Icon(Icons.style_outlined, color: Colors.orangeAccent);
    }
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
                size: 100, color: theme.iconTheme.color),
            const SizedBox(height: 24),
            Text('No $typeName yet', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              'Tap the + button to create your first set of study materials!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResultsState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_outlined,
                size: 100, color: theme.iconTheme.color),
            const SizedBox(height: 24),
            Text('No Results Found', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              'Your search for "$_searchQuery" did not match any content. Try a different search term.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.article_outlined, color: theme.iconTheme.color),
            title: Text('Create Summary', style: theme.textTheme.bodyMedium),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SummaryScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.quiz_outlined, color: theme.iconTheme.color),
            title: Text('Create Quiz', style: theme.textTheme.bodyMedium),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const QuizScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.style_outlined, color: theme.iconTheme.color),
            title: Text('Create Flashcards', style: theme.textTheme.bodyMedium),
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
    );
  }

  void _showItemMenu(
      BuildContext context, String userId, LibraryItem item, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.edit_outlined, color: theme.iconTheme.color),
            title: Text('Edit', style: theme.textTheme.bodyMedium),
            onTap: () {
              Navigator.pop(ctx);
              _editContent(context, userId, item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(ctx);
              _deleteContent(context, userId, item);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToContent(
      BuildContext context, String userId, LibraryItem item) async {

    Widget? screen;
    switch (item.type) {
      case LibraryItemType.summary:
        if (_isOfflineMode) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Navigation is disabled in offline mode.')));
          }
          return;
        }
        final content = await _firestoreService.getSpecificItem(userId, item);

        if (content != null) {
          final summary = content as Summary;
          screen = SummaryScreen(summary: LocalSummary(id: summary.id, title: summary.title, content: summary.content, timestamp: summary.timestamp.toDate(), userId: userId));
        }
        break;
      case LibraryItemType.quiz:
        final localQuiz = await _localDb.getQuiz(item.id);
        if (localQuiz != null) {
          screen = QuizScreen(quiz: localQuiz);
        }
        break;
      case LibraryItemType.flashcards:
        if (_isOfflineMode) {
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Navigation is disabled in offline mode.')));
          }
          return;
        }
        final content = await _firestoreService.getSpecificItem(userId, item);
        if (content != null) {
          screen = FlashcardsScreen(flashcardSet: content as FlashcardSet);
        }
        break;
    }


    if (screen != null) {
      if(mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => screen!));
      }
    } else {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not load content.')));
      }
    }
  }

  Future<void> _editContent(
      BuildContext context, String userId, LibraryItem item) async {

    if (_isOfflineMode) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Editing is disabled in offline mode.')));
      }
      return;
    }

    final content = await _firestoreService.getSpecificItem(userId, item);
    if (content == null) return;

    EditableContent? editableContent;
    switch (item.type) {
      case LibraryItemType.summary:
        final summary = content as Summary;
        editableContent = EditableContent.fromSummary(summary.id, summary.title,
            summary.content, summary.tags, summary.timestamp);
        break;
      case LibraryItemType.quiz:
        final quiz = content as Quiz;
        editableContent = EditableContent.fromQuiz(
            quiz.id, quiz.title, quiz.questions, quiz.timestamp);
        break;
      case LibraryItemType.flashcards:
        final flashcardSet = content as FlashcardSet;
        editableContent = EditableContent.fromFlashcardSet(
            flashcardSet.id,
            flashcardSet.title,
            flashcardSet.flashcards,
            flashcardSet.timestamp);
        break;
    }

    if (mounted && editableContent != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                EditContentScreen(content: editableContent!)));
    }
  }

  Future<void> _deleteContent(
      BuildContext context, String userId, LibraryItem item) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Delete Content', style: theme.textTheme.headlineSmall),
        content: Text('Are you sure you want to delete this item?',
            style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel',
                  style: TextStyle(color: theme.colorScheme.onSurface))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed == null || !confirmed) return;

    try {
      if (item.type == LibraryItemType.quiz) {
        await _localDb.deleteQuiz(item.id);
        if (mounted) {
          Provider.of<QuizViewModel>(context, listen: false).refresh();
        }
      } else {
        if (_isOfflineMode) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Deletion of cloud items is disabled in offline mode.')));
          }
          return;
        }
        await _firestoreService.deleteItem(userId, item);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Item deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error deleting item: $e')));
      }
    }
  }
}
