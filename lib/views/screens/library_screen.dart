import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_model.dart';
import '../../models/library_item.dart';
import '../../models/folder.dart';
import '../../models/editable_content.dart';
import '../../models/local_summary.dart';
import '../../models/local_quiz.dart';
import '../../models/local_flashcard_set.dart';
import '../../models/quiz_question.dart';
import '../../models/flashcard.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';
import '../../services/sync_service.dart';
import '../../view_models/library_view_model.dart';

import '../screens/summary_screen.dart';
import '../screens/quiz_screen.dart';
import '../screens/flashcards_screen.dart';
import '../screens/edit_summary_screen.dart';
import '../screens/edit_quiz_screen.dart';
import '../screens/edit_flashcards_screen.dart';
import '../widgets/enter_code_dialog.dart';
import '../../utils/library_share_helper.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final theme = Theme.of(context);

    if (user == null) {
      return _buildLoggedOutView(theme);
    }

    return ChangeNotifierProvider(
      create: (context) => LibraryViewModel(
        localDb: context.read<LocalDatabaseService>(),
        firestoreService: context.read<FirestoreService>(),
        syncService: context.read<SyncService>(),
        userId: user.uid,
      ),
      child: const _LibraryView(),
    );
  }

  Widget _buildLoggedOutView(ThemeData theme) {
    return Scaffold(
      body: Center(
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
                      color: theme.colorScheme.onSurface.withAlpha(153)),
                ),
              ],
            ),
          ),
        ),
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
            color: theme.cardColor.withAlpha(178),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: theme.cardColor.withAlpha(230), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
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
}

class _LibraryView extends StatefulWidget {
  const _LibraryView();

  @override
  _LibraryViewState createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView>
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _folderTabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 5, vsync: this);
    _folderTabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _folderTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<LibraryViewModel>();

    return Scaffold(
      appBar: _buildAppBar(context, theme, viewModel),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const EnterCodeDialog(),
          );
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Enter Code'),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: Column(
        children: [
          _buildSearchAndTabs(context, theme, viewModel),
          Expanded(
            child: StreamBuilder<Folder?>(
              stream: viewModel.selectedFolderStream,
              builder: (context, snapshot) {
                final selectedFolder = snapshot.data;
                if (selectedFolder == null) {
                  return TabBarView(
                    key: const ValueKey('main_tab_view'),
                    controller: _mainTabController,
                    children: [
                      _buildFolderList(viewModel, theme),
                      _buildContentList(viewModel.allItems$, theme, viewModel),
                      _buildContentList(
                          viewModel.allSummaries$, theme, viewModel),
                      _buildContentList(
                          viewModel.allQuizzes$, theme, viewModel),
                      _buildContentList(
                          viewModel.allFlashcards$, theme, viewModel),
                    ],
                  );
                } else {
                  return TabBarView(
                    key: const ValueKey('folder_tab_view'),
                    controller: _folderTabController,
                    children: [
                      _buildContentList(
                          viewModel.getFolderItemsStream(selectedFolder.id),
                          theme,
                          viewModel),
                      _buildContentList(
                          viewModel.getFolderSummariesStream(selectedFolder.id),
                          theme,
                          viewModel),
                      _buildContentList(
                          viewModel.getFolderQuizzesStream(selectedFolder.id),
                          theme,
                          viewModel),
                      _buildContentList(
                          viewModel
                              .getFolderFlashcardsStream(selectedFolder.id),
                          theme,
                          viewModel),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(
      BuildContext context, ThemeData theme, LibraryViewModel viewModel) {
    final selectedFolder = viewModel.selectedFolder;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: selectedFolder != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => viewModel.selectFolder(null),
            )
          : null,
      title: Text(selectedFolder?.name ?? 'Library',
          style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
      centerTitle: true,
      actions: [
        if (viewModel.isSyncing)
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          IconButton(
              icon: const Icon(Icons.sync), onPressed: viewModel.syncAllData),
      ],
    );
  }

  Widget _buildSearchAndTabs(
      BuildContext context, ThemeData theme, LibraryViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor.withAlpha((255 * 0.7).round()),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
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
                    color: theme.colorScheme.onSurface.withAlpha(128)),
                prefixIcon: Icon(Icons.search,
                    color: theme.colorScheme.onSurface.withAlpha(128)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
              ),
            ),
          ).animate().fadeIn().slideY(begin: -0.2),
          const SizedBox(height: 16),
          _buildTabBar(context, theme, viewModel),
        ],
      ),
    );
  }

  Widget _buildTabBar(
      BuildContext context, ThemeData theme, LibraryViewModel viewModel) {
    final selectedFolder = viewModel.selectedFolder;
    return TabBar(
      controller:
          selectedFolder == null ? _mainTabController : _folderTabController,
      isScrollable: true,
      tabs: selectedFolder == null
          ? const [
              Tab(text: 'Folders'),
              Tab(text: 'All'),
              Tab(text: 'Summaries'),
              Tab(text: 'Quizzes'),
              Tab(text: 'Flashcards')
            ]
          : const [
              Tab(text: 'All'),
              Tab(text: 'Summaries'),
              Tab(text: 'Quizzes'),
              Tab(text: 'Flashcards')
            ],
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: theme.colorScheme.primary,
      ),
      labelStyle:
          theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
      unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(153),
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

  Widget _buildFolderList(LibraryViewModel viewModel, ThemeData theme) {
    return StreamBuilder<List<Folder>>(
      stream: viewModel.allFolders$,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoContentState('folders', theme);
        }

        final folders = snapshot.data!;
        final filteredFolders = _searchQuery.isEmpty
            ? folders
            : folders
                .where((folder) =>
                    folder.name.toLowerCase().contains(_searchQuery))
                .toList();

        if (filteredFolders.isEmpty && _searchQuery.isNotEmpty) {
          return _buildNoSearchResultsState(theme);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredFolders.length,
          itemBuilder: (context, index) {
            final folder = filteredFolders[index];
            return _buildGlassListTile(
              title: folder.name,
              subtitle: 'Created: ${folder.createdAt.toString().split(' ')[0]}',
              icon: Icons.folder,
              iconColor: Colors.amber,
              theme: theme,
              onTap: () => viewModel.selectFolder(folder),
            )
                .animate()
                .fadeIn(delay: (50 * index).ms)
                .slideY(begin: 0.1, duration: 300.ms);
          },
        );
      },
    );
  }

  Widget _buildContentList(Stream<List<LibraryItem>> stream, ThemeData theme,
      LibraryViewModel viewModel) {
    return StreamBuilder<List<LibraryItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoContentState(
              viewModel.selectedFolder == null ? 'content' : 'folder content',
              theme);
        }

        final items = snapshot.data!
            .where((item) => item.title.toLowerCase().contains(_searchQuery))
            .toList();

        if (items.isEmpty && _searchQuery.isNotEmpty) {
          return _buildNoSearchResultsState(theme);
        }

        return RefreshIndicator(
          onRefresh: viewModel.syncAllData,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 80.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => viewModel.deleteItem(item),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(204),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: _buildLibraryCard(item, theme,
                    () => _navigateToContent(context, item, viewModel)),
              )
                  .animate()
                  .fadeIn(delay: (50 * index).ms)
                  .slideY(begin: 0.1, duration: 300.ms);
            },
          ),
        );
      },
    );
  }

  Widget _buildLibraryCard(
      LibraryItem item, ThemeData theme, VoidCallback onTap) {
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

    return _buildGlassListTile(
      title: item.title,
      subtitle: item.type.toString().split('.').last.toUpperCase(),
      icon: icon,
      iconColor: iconColor,
      theme: theme,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Creator badge if imported
          if (item.creatorName != null && item.creatorName!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withAlpha(77)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    item.creatorName!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          // Share menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert,
                color: theme.colorScheme.onSurface.withAlpha(153)),
            onSelected: (value) async {
              if (value == 'share') {
                final user = context.read<UserModel?>();
                if (user != null) {
                  await LibraryShareHelper.shareLibraryItem(
                      context, item, user);
                }
              } else if (value == 'edit') {
                _navigateToEdit(context, item);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 12),
                    Text('Share'),
                  ],
                ),
              ),
            ],
          ),
        ],
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
        color: theme.cardColor.withAlpha(153),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardColor.withAlpha(178), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
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
                    color: iconColor.withAlpha(26),
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
                              color: theme.colorScheme.onSurface.withAlpha(153),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  Icon(Icons.chevron_right,
                      color: theme.colorScheme.onSurface.withAlpha(77)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoContentState(String type, ThemeData theme) {
    String title, message;
    switch (type) {
      case 'folders':
        title = 'No folders yet';
        message = 'Create your first folder to organize your study materials!';
        break;
      case 'folder content':
        title = 'This folder is empty';
        message = 'Add some content to this folder to see it here.';
        break;
      default:
        title = 'No content yet';
        message =
            'Tap the + button to create your first set of study materials!';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined,
                size: 100, color: theme.colorScheme.primary.withAlpha(51)),
            const SizedBox(height: 24),
            Text(title,
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withAlpha(153))),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(128)),
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
                size: 100, color: theme.colorScheme.primary.withAlpha(51)),
            const SizedBox(height: 24),
            Text('No Results Found',
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withAlpha(153))),
            const SizedBox(height: 12),
            Text(
              'Your search for "$_searchQuery" did not match any content. Try a different search term.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(128)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Future<void> _navigateToContent(BuildContext context, LibraryItem item,
      LibraryViewModel viewModel) async {
    if (!mounted) return;
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) return;

    try {
      // Get the specific content based on its type
      dynamic contentData;
      switch (item.type) {
        case LibraryItemType.summary:
          contentData = await viewModel.localDb.getSummary(item.id);
          break;
        case LibraryItemType.quiz:
          contentData = await viewModel.localDb.getQuiz(item.id);
          break;
        case LibraryItemType.flashcards:
          contentData = await viewModel.localDb.getFlashcardSet(item.id);
          break;
      }

      if (!mounted) return;

      if (contentData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Could not load content.')),
          );
        }
        return;
      }

      Widget screen;
      switch (item.type) {
        case LibraryItemType.summary:
          screen = SummaryScreen(summary: contentData);
          break;
        case LibraryItemType.quiz:
          screen = QuizScreen(quiz: contentData);
          break;
        case LibraryItemType.flashcards:
          screen = FlashcardsScreen(flashcardSet: contentData);
          break;
      }

      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
  }

  Future<void> _navigateToEdit(BuildContext context, LibraryItem item) async {
    if (!mounted) return;
    final user = Provider.of<UserModel?>(context, listen: false);
    final viewModel = context.read<LibraryViewModel>();
    if (user == null) return;

    try {
      // Get the specific content based on its type
      dynamic contentData;
      switch (item.type) {
        case LibraryItemType.summary:
          contentData = await viewModel.localDb.getSummary(item.id);
          break;
        case LibraryItemType.quiz:
          contentData = await viewModel.localDb.getQuiz(item.id);
          break;
        case LibraryItemType.flashcards:
          contentData = await viewModel.localDb.getFlashcardSet(item.id);
          break;
      }

      if (!mounted) return;

      if (contentData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error: Could not load content for editing.')),
          );
        }
        return;
      }

      // Convert to EditableContent
      EditableContent editableContent;
      switch (item.type) {
        case LibraryItemType.summary:
          final summary = contentData as LocalSummary;
          editableContent = EditableContent(
            id: summary.id,
            type: 'summary',
            title: summary.title,
            content: summary.content,
            tags: summary.tags,
            timestamp: Timestamp.fromDate(summary.timestamp),
          );
          break;
        case LibraryItemType.quiz:
          final quiz = contentData as LocalQuiz;
          final quizQuestions = quiz.questions
              .map((q) => QuizQuestion(
                    question: q.question,
                    options: q.options,
                    correctAnswer: q.correctAnswer,
                  ))
              .toList();
          editableContent = EditableContent(
            id: quiz.id,
            type: 'quiz',
            title: quiz.title,
            questions: quizQuestions,
            timestamp: Timestamp.fromDate(quiz.timestamp),
          );
          break;
        case LibraryItemType.flashcards:
          final flashcardSet = contentData as LocalFlashcardSet;
          final flashcards = flashcardSet.flashcards
              .map((f) => Flashcard(
                    id: f.id,
                    question: f.question,
                    answer: f.answer,
                  ))
              .toList();
          editableContent = EditableContent(
            id: flashcardSet.id,
            type: 'flashcards',
            title: flashcardSet.title,
            flashcards: flashcards,
            timestamp: Timestamp.fromDate(flashcardSet.timestamp),
          );
          break;
      }

      Widget editScreen;
      switch (item.type) {
        case LibraryItemType.summary:
          editScreen = EditSummaryScreen(content: editableContent);
          break;
        case LibraryItemType.quiz:
          editScreen = EditQuizScreen(content: editableContent);
          break;
        case LibraryItemType.flashcards:
          editScreen = EditFlashcardsScreen(content: editableContent);
          break;
      }

      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => editScreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
  }
}
