import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:go_router/go_router.dart';

class DataStorageScreen extends StatelessWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localDB = Provider.of<LocalDatabaseService>(context);
    final user = Provider.of<UserModel?>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Data & Storage',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildStorageInfoCard(context, theme),
              const SizedBox(height: 24),
              _buildSectionHeader(theme, 'Manage Data'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                ),
                color: theme.cardColor,
                child: Column(
                  children: [
                    _buildActionTile(
                      context,
                      icon: Icons.cleaning_services_outlined,
                      title: 'Clear Cache',
                      subtitle: 'Free up space',
                      onTap: () =>
                          _showClearCacheConfirmation(context, localDB),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                          height: 1,
                          color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    _buildActionTile(
                      context,
                      icon: Icons.offline_pin_outlined,
                      title: 'Offline Files',
                      subtitle: 'Manage downloads',
                      onTap: () =>
                          _showOfflineFilesModal(context, theme, localDB, user),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                          height: 1,
                          color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    _buildActionTile(
                      context,
                      icon: Icons.sync_outlined,
                      title: 'Sync Data',
                      subtitle: 'Sync with cloud',
                      onTap: () => _syncData(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildStorageInfoCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage_outlined,
                    color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Storage Usage',
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '42.5 MB Used',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: 0.42,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surface,
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0 MB', style: theme.textTheme.bodySmall),
                Text('100 MB Limit', style: theme.textTheme.bodySmall),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Text(subtitle,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      trailing: Icon(Icons.arrow_forward_ios,
          size: 16, color: theme.colorScheme.onSurface.withOpacity(0.3)),
    );
  }

  void _showClearCacheConfirmation(
      BuildContext context, LocalDatabaseService localDB) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Cache?'),
          content: const Text(
              'Are you sure you want to clear all cached data? This will free up storage space but may require re-downloading content.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Clear',
                  style: TextStyle(color: theme.colorScheme.error)),
              onPressed: () {
                localDB.clearAllData();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cache cleared successfully.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showOfflineFilesModal(BuildContext context, ThemeData theme,
      LocalDatabaseService localDB, UserModel? user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Offline Files',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (user != null)
                FutureBuilder(
                  future: Future.wait([
                    localDB.getAllSummaries(user.uid),
                    localDB.getAllQuizzes(user.uid),
                    localDB.getAllFlashcardSets(user.uid),
                  ]),
                  builder:
                      (context, AsyncSnapshot<List<List<dynamic>>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData ||
                        snapshot.data!.every((list) => list.isEmpty)) {
                      return Center(
                        child: Column(
                          children: [
                            Icon(Icons.folder_open,
                                size: 48, color: theme.disabledColor),
                            const SizedBox(height: 16),
                            Text(
                              'No offline files yet.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    final summaries = snapshot.data![0] as List<LocalSummary>;
                    final quizzes = snapshot.data![1] as List<LocalQuiz>;
                    final flashcardSets =
                        snapshot.data![2] as List<LocalFlashcardSet>;

                    return SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ...summaries.map((summary) => _buildOfflineFileTile(
                              context,
                              theme,
                              localDB,
                              'Summary',
                              summary.title,
                              summary.id,
                              () => localDB.deleteSummary(summary.id))),
                          ...quizzes.map((quiz) => _buildOfflineFileTile(
                              context,
                              theme,
                              localDB,
                              'Quiz',
                              quiz.title,
                              quiz.id,
                              () => localDB.deleteQuiz(quiz.id))),
                          ...flashcardSets.map((flashcardSet) =>
                              _buildOfflineFileTile(
                                  context,
                                  theme,
                                  localDB,
                                  'Flashcard Set',
                                  flashcardSet.title,
                                  flashcardSet.id,
                                  () => localDB
                                      .deleteFlashcardSet(flashcardSet.id))),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfflineFileTile(
      BuildContext context,
      ThemeData theme,
      LocalDatabaseService localDB,
      String type,
      String title,
      String id,
      VoidCallback onDelete) {
    return Card(
      elevation: 0,
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
      child: ListTile(
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(type, style: theme.textTheme.bodySmall),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          onPressed: () {
            onDelete();
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title deleted.'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  void _syncData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Syncing data...'),
        duration: Duration(seconds: 2),
      ),
    );
    // TODO: Implement actual sync functionality
  }
}
