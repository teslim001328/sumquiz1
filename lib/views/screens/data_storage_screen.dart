import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DataStorageScreen extends StatelessWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localDB = Provider.of<LocalDatabaseService>(context);
    final user = Provider.of<UserModel?>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Data & Storage',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
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
                                theme.colorScheme.surface,
                                Color.lerp(theme.colorScheme.surface,
                                    theme.colorScheme.primaryContainer, value)!,
                              ]
                            : [
                                const Color(0xFFF3F4F6),
                                Color.lerp(const Color(0xFFE8EAF6),
                                    const Color(0xFFC5CAE9), value)!,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      _buildStorageInfoCard(context, localDB, user, theme)
                          .animate()
                          .fadeIn(delay: 100.ms)
                          .slideY(begin: 0.1),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Manage Data', theme)
                          .animate()
                          .fadeIn(delay: 200.ms),
                      _buildGlassContainer(
                        theme: theme,
                        child: Column(
                          children: [
                            _buildActionTile(
                              context,
                              icon: Icons.cleaning_services_outlined,
                              title: 'Clear Cache',
                              subtitle: 'Free up space',
                              onTap: () => _showClearCacheConfirmation(
                                  context, localDB, theme),
                              theme: theme,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child:
                                  Divider(height: 1, color: theme.dividerColor),
                            ),
                            _buildActionTile(
                              context,
                              icon: Icons.offline_pin_outlined,
                              title: 'Offline Files',
                              subtitle: 'Manage downloads',
                              onTap: () => _showOfflineFilesModal(
                                  context, localDB, user, theme),
                              theme: theme,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child:
                                  Divider(height: 1, color: theme.dividerColor),
                            ),
                            _buildActionTile(
                              context,
                              icon: Icons.sync_outlined,
                              title: 'Sync Data',
                              subtitle: 'Sync with cloud',
                              onTap: () => _syncData(context),
                              theme: theme,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer(
      {required Widget child, required ThemeData theme}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.cardColor.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
              fontSize: 12,
            ) ??
            theme.textTheme.labelSmall?.copyWith(
              // Fallback if labelFloating doesn't exist
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
      ),
    );
  }

  Widget _buildStorageInfoCard(BuildContext context,
      LocalDatabaseService localDB, UserModel? user, ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.storage_outlined,
                          color: theme.colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Storage Usage',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (user != null)
                  FutureBuilder<double>(
                    future: _calculateStorageUsage(localDB, user.uid),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final usageMB = snapshot.data!;
                      final usagePercent = (usageMB / 100).clamp(0.0, 1.0);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${usageMB.toStringAsFixed(1)} MB Used',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                                fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: usagePercent,
                              minHeight: 10,
                              backgroundColor:
                                  theme.disabledColor.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('0 MB',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.disabledColor,
                                      fontSize: 12)),
                              Text('100 MB Limit',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.disabledColor,
                                      fontSize: 12)),
                            ],
                          )
                        ],
                      );
                    },
                  )
                else
                  const Center(
                    child: Text('Please log in to see storage usage'),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      required ThemeData theme}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurface, fontSize: 16)),
      subtitle: Text(subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13)),
      trailing: Icon(Icons.arrow_forward_ios,
          size: 14, color: theme.disabledColor.withValues(alpha: 0.4)),
    );
  }

  void _showClearCacheConfirmation(
      BuildContext context, LocalDatabaseService localDB, ThemeData theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor:
              theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          title: Text('Clear Cache?',
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: theme.colorScheme.onSurface)),
          content: Text(
              'Are you sure you want to clear all cached data? This will free up storage space but may require re-downloading content.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Clear',
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                localDB.clearAllData();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cache cleared successfully.'),
                    duration: Duration(seconds: 3),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showOfflineFilesModal(BuildContext context,
      LocalDatabaseService localDB, UserModel? user, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.9),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top:
                      BorderSide(color: theme.cardColor.withValues(alpha: 0.6)),
                ),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.disabledColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Offline Files',
                    style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 24),
                  if (user != null)
                    Expanded(
                      child: FutureBuilder(
                        future: Future.wait([
                          localDB.getAllSummaries(user.uid),
                          localDB.getAllQuizzes(user.uid),
                          localDB.getAllFlashcardSets(user.uid),
                        ]),
                        builder: (context,
                            AsyncSnapshot<List<List<dynamic>>> snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.every((list) => list.isEmpty)) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_open,
                                      size: 48, color: theme.disabledColor),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No offline files yet.',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: theme.disabledColor),
                                  ),
                                ],
                              ),
                            );
                          }

                          final summaries =
                              snapshot.data![0] as List<LocalSummary>;
                          final quizzes = snapshot.data![1] as List<LocalQuiz>;
                          final flashcardSets =
                              snapshot.data![2] as List<LocalFlashcardSet>;

                          return ListView(
                            children: [
                              ...summaries.map((summary) =>
                                  _buildOfflineFileTile(
                                      context,
                                      localDB,
                                      'Summary',
                                      summary.title,
                                      summary.id,
                                      () => localDB.deleteSummary(summary.id),
                                      theme)),
                              ...quizzes.map((quiz) => _buildOfflineFileTile(
                                  context,
                                  localDB,
                                  'Quiz',
                                  quiz.title,
                                  quiz.id,
                                  () => localDB.deleteQuiz(quiz.id),
                                  theme)),
                              ...flashcardSets.map((flashcardSet) =>
                                  _buildOfflineFileTile(
                                      context,
                                      localDB,
                                      'Flashcard Set',
                                      flashcardSet.title,
                                      flashcardSet.id,
                                      () => localDB
                                          .deleteFlashcardSet(flashcardSet.id),
                                      theme)),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfflineFileTile(
      BuildContext context,
      LocalDatabaseService localDB,
      String type,
      String title,
      String id,
      VoidCallback onDelete,
      ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.disabledColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.disabledColor.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        title: Text(title,
            style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500)),
        subtitle: Text(type,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.disabledColor, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              color: Colors.redAccent, size: 20),
          onPressed: () {
            onDelete();
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title deleted.'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.redAccent,
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

  Future<double> _calculateStorageUsage(
      LocalDatabaseService localDB, String userId) async {
    try {
      // Initialize database if not already done
      await localDB.init();

      // Get counts of all stored items
      final summaries = await localDB.getAllSummaries(userId);
      final quizzes = await localDB.getAllQuizzes(userId);
      final flashcardSets = await localDB.getAllFlashcardSets(userId);
      final folders = await localDB.getAllFolders(userId);

      // Estimate storage usage based on item counts
      // Rough estimates: Summary (~2KB), Quiz (~3KB), FlashcardSet (~4KB), Folder (~0.5KB)
      const double summarySizeKB = 2.0;
      const double quizSizeKB = 3.0;
      const double flashcardSetSizeKB = 4.0;
      const double folderSizeKB = 0.5;

      final totalKB = (summaries.length * summarySizeKB) +
          (quizzes.length * quizSizeKB) +
          (flashcardSets.length * flashcardSetSizeKB) +
          (folders.length * folderSizeKB);

      // Convert to MB and add some overhead
      final totalMB = (totalKB / 1024) + 0.5; // Add 0.5MB overhead for metadata

      return totalMB.clamp(0.1, 100.0); // Clamp between 0.1MB and 100MB
    } catch (e) {
      debugPrint('Error calculating storage usage: $e');
      return 0.1; // Return minimum value on error
    }
  }
}
