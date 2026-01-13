import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:developer' as developer;

import '../models/folder.dart';
import '../models/library_item.dart';
import '../services/local_database_service.dart';
import '../services/firestore_service.dart';
import '../services/sync_service.dart';

class LibraryViewModel with ChangeNotifier {
  final LocalDatabaseService localDb;
  final FirestoreService firestoreService;
  final SyncService syncService;
  final String userId;

  final _selectedFolderController = BehaviorSubject<Folder?>.seeded(null);
  Stream<Folder?> get selectedFolderStream => _selectedFolderController.stream;
  Folder? get selectedFolder => _selectedFolderController.value;

  final _isSyncing = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get isSyncingStream => _isSyncing.stream;
  bool get isSyncing => _isSyncing.value;

  late Stream<List<LibraryItem>> allItems$;
  late Stream<List<LibraryItem>> allSummaries$;
  late Stream<List<LibraryItem>> allQuizzes$;
  late Stream<List<LibraryItem>> allFlashcards$;
  late Stream<List<Folder>> allFolders$;

  LibraryViewModel({
    required this.localDb,
    required this.firestoreService,
    required this.syncService,
    required this.userId,
  }) {
    _initializeStreams();
    syncAllData();
  }

  void _initializeStreams() {
    allFolders$ = localDb.watchAllFolders(userId);

    // Create independent streams for each content type
    final allSummariesFromDb$ = localDb.watchAllSummaries(userId)
        .map((summaries) => summaries.map(LibraryItem.fromLocalSummary).toList());
    final allQuizzesFromDb$ = localDb.watchAllQuizzes(userId)
        .map((quizzes) => quizzes.map(LibraryItem.fromLocalQuiz).toList());
    final allFlashcardsFromDb$ = localDb.watchAllFlashcardSets(userId)
        .map((flashcards) => flashcards.map(LibraryItem.fromLocalFlashcardSet).toList());

    // Combine all items without folder filtering
    final allItemsCombined$ = Rx.combineLatest3<List<LibraryItem>,
            List<LibraryItem>, List<LibraryItem>, List<LibraryItem>>(
        allSummariesFromDb$,
        allQuizzesFromDb$,
        allFlashcardsFromDb$,
        (summaries, quizzes, flashcards) =>
            [...summaries, ...quizzes, ...flashcards]);

    // Main allItems$ stream with folder filtering
    allItems$ = selectedFolderStream.switchMap((folder) {
      if (folder == null) {
        // Return all items when no folder is selected
        return allItemsCombined$;
      } else {
        // Watch folder contents and filter items
        return localDb.watchContentIdsInFolder(folder.id).switchMap((contentIds) {
          // For each contentIds update, filter the combined items
          return allItemsCombined$.map((allItems) {
            return allItems.where((item) => contentIds.contains(item.id)).toList();
          });
        });
      }
    });

    // Create filtered streams for each content type
    allSummaries$ = allItems$.map((items) =>
        items.where((item) => item.type == LibraryItemType.summary).toList());
    allQuizzes$ = allItems$.map((items) =>
        items.where((item) => item.type == LibraryItemType.quiz).toList());
    allFlashcards$ = allItems$.map((items) =>
        items.where((item) => item.type == LibraryItemType.flashcards).toList());
  }

  // Helper methods for folder-specific content
  Stream<List<LibraryItem>> getFolderItemsStream(String folderId) {
    return localDb.watchContentIdsInFolder(folderId).switchMap((contentIds) {
      return Rx.combineLatest3<List<LibraryItem>,
          List<LibraryItem>, List<LibraryItem>, List<LibraryItem>>(
        localDb.watchAllSummaries(userId)
            .map((summaries) => summaries
                .where((s) => contentIds.contains(s.id))
                .map(LibraryItem.fromLocalSummary)
                .toList()),
        localDb.watchAllQuizzes(userId)
            .map((quizzes) => quizzes
                .where((q) => contentIds.contains(q.id))
                .map(LibraryItem.fromLocalQuiz)
                .toList()),
        localDb.watchAllFlashcardSets(userId)
            .map((flashcards) => flashcards
                .where((f) => contentIds.contains(f.id))
                .map(LibraryItem.fromLocalFlashcardSet)
                .toList()),
        (summaries, quizzes, flashcards) =>
            [...summaries, ...quizzes, ...flashcards],
      );
    });
  }

  Stream<List<LibraryItem>> getFolderSummariesStream(String folderId) {
    return localDb.watchContentIdsInFolder(folderId).switchMap((contentIds) {
      return localDb.watchAllSummaries(userId).map((summaries) {
        return summaries
            .where((summary) => contentIds.contains(summary.id))
            .map(LibraryItem.fromLocalSummary)
            .toList();
      });
    });
  }

  Stream<List<LibraryItem>> getFolderQuizzesStream(String folderId) {
    return localDb.watchContentIdsInFolder(folderId).switchMap((contentIds) {
      return localDb.watchAllQuizzes(userId).map((quizzes) {
        return quizzes
            .where((quiz) => contentIds.contains(quiz.id))
            .map(LibraryItem.fromLocalQuiz)
            .toList();
      });
    });
  }

  Stream<List<LibraryItem>> getFolderFlashcardsStream(String folderId) {
    return localDb.watchContentIdsInFolder(folderId).switchMap((contentIds) {
      return localDb.watchAllFlashcardSets(userId).map((flashcardSets) {
        return flashcardSets
            .where((set) => contentIds.contains(set.id))
            .map(LibraryItem.fromLocalFlashcardSet)
            .toList();
      });
    });
  }

  void selectFolder(Folder? folder) {
    _selectedFolderController.add(folder);
  }

  Future<void> syncAllData() async {
    if (_isSyncing.value) return;
    _isSyncing.add(true);
    notifyListeners();

    try {
      await syncService.syncAllData();
    } catch (e, s) {
      developer.log('Error during sync', name: 'LibraryViewModel', error: e, stackTrace: s);
    } finally {
      _isSyncing.add(false);
      notifyListeners();
    }
  }

  Future<void> deleteItem(LibraryItem item) async {
    try {
      switch (item.type) {
        case LibraryItemType.summary:
          await localDb.deleteSummary(item.id);
          break;
        case LibraryItemType.quiz:
          await localDb.deleteQuiz(item.id);
          break;
        case LibraryItemType.flashcards:
          await localDb.deleteFlashcardSet(item.id);
          break;
      }
      await firestoreService.deleteItem(userId, item);
    } catch (e, s) {
      developer.log('Error deleting item', name: 'LibraryViewModel', error: e, stackTrace: s);
    }
  }
  
  @override
  void dispose() {
    _selectedFolderController.close();
    _isSyncing.close();
    super.dispose();
  }
}