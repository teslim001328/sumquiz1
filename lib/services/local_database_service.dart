import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';

import '../models/local_summary.dart';
import '../models/local_quiz.dart';
import '../models/local_quiz_question.dart';
import '../models/local_flashcard.dart';
import '../models/local_flashcard_set.dart';
import '../models/folder.dart';
import '../models/content_folder.dart';
import '../models/spaced_repetition.dart';
import '../models/daily_mission.dart';

class LocalDatabaseService {
  // Box names
  static const String _summariesBoxName = 'summaries';
  static const String _quizzesBoxName = 'quizzes';
  static const String _flashcardSetsBoxName = 'flashcardSets';
  static const String _foldersBoxName = 'folders';
  static const String _contentFoldersBoxName = 'contentFolders';
  static const String _spacedRepetitionBoxName = 'spaced_repetition';
  static const String _dailyMissionsBoxName = 'daily_missions';
  static const String _settingsBoxName = 'settings';

  // Hive Boxes - late initialized
  late Box<LocalSummary> _summariesBox;
  late Box<LocalQuiz> _quizzesBox;
  late Box<LocalFlashcardSet> _flashcardSetsBox;
  late Box<Folder> _foldersBox;
  late Box<ContentFolder> _contentFoldersBox;
  late Box<SpacedRepetitionItem> _spacedRepetitionBox;
  late Box<DailyMission> _dailyMissionsBox;
  late Box _settingsBox;

  // Singleton pattern
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      // Register adapters only if they haven't been registered yet
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(LocalSummaryAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(LocalQuizAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(LocalQuizQuestionAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(LocalFlashcardAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(LocalFlashcardSetAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(FolderAdapter());
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(ContentFolderAdapter());
      }
      if (!Hive.isAdapterRegistered(8)) {
        Hive.registerAdapter(SpacedRepetitionItemAdapter());
      }
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(DailyMissionAdapter());
      }

      // Open boxes
      _summariesBox = await Hive.openBox<LocalSummary>(_summariesBoxName);
      _quizzesBox = await Hive.openBox<LocalQuiz>(_quizzesBoxName);
      _flashcardSetsBox =
          await Hive.openBox<LocalFlashcardSet>(_flashcardSetsBoxName);
      _foldersBox = await Hive.openBox<Folder>(_foldersBoxName);
      _contentFoldersBox =
          await Hive.openBox<ContentFolder>(_contentFoldersBoxName);
      _spacedRepetitionBox =
          await Hive.openBox<SpacedRepetitionItem>(_spacedRepetitionBoxName);
      _dailyMissionsBox =
          await Hive.openBox<DailyMission>(_dailyMissionsBoxName);
      _settingsBox = await Hive.openBox(_settingsBoxName);

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing local database: $e');
      rethrow;
    }
  }

  // --- WATCH METHODS ---

  Stream<List<Folder>> watchAllFolders(String userId) async* {
    await init();
    yield _foldersBox.values.where((f) => f.userId == userId).toList();
    await for (final _ in _foldersBox.watch()) {
      yield _foldersBox.values.where((f) => f.userId == userId).toList();
    }
  }

  Stream<List<LocalSummary>> watchAllSummaries(String userId) async* {
    await init();
    yield _summariesBox.values.where((s) => s.userId == userId).toList();
    await for (final _ in _summariesBox.watch()) {
      yield _summariesBox.values.where((s) => s.userId == userId).toList();
    }
  }

  Stream<List<LocalQuiz>> watchAllQuizzes(String userId) async* {
    await init();
    yield _quizzesBox.values.where((q) => q.userId == userId).toList();
    await for (final _ in _quizzesBox.watch()) {
      yield _quizzesBox.values.where((q) => q.userId == userId).toList();
    }
  }

  Stream<List<LocalFlashcardSet>> watchAllFlashcardSets(String userId) async* {
    await init();
    yield _flashcardSetsBox.values.where((fs) => fs.userId == userId).toList();
    await for (final _ in _flashcardSetsBox.watch()) {
      yield _flashcardSetsBox.values
          .where((fs) => fs.userId == userId)
          .toList();
    }
  }

  Stream<List<String>> watchContentIdsInFolder(String folderId) async* {
    await init();
    yield _contentFoldersBox.values
        .where((cf) => cf.folderId == folderId)
        .map((cf) => cf.contentId)
        .toList();
    await for (final _ in _contentFoldersBox.watch()) {
      yield _contentFoldersBox.values
          .where((cf) => cf.folderId == folderId)
          .map((cf) => cf.contentId)
          .toList();
    }
  }

  // --- CRUD & SYNC OPERATIONS ---

  Future<void> saveSummary(LocalSummary summary, [String? folderId]) async {
    await init();
    await _summariesBox.put(summary.id, summary);
    if (folderId != null) {
      await assignContentToFolder(
          summary.id, folderId, 'summary', summary.userId);
    }
  }

  Future<void> saveQuiz(LocalQuiz quiz, [String? folderId]) async {
    await init();
    await _quizzesBox.put(quiz.id, quiz);
    if (folderId != null) {
      await assignContentToFolder(quiz.id, folderId, 'quiz', quiz.userId);
    }
  }

  Future<void> saveFlashcardSet(LocalFlashcardSet flashcardSet,
      [String? folderId]) async {
    await init();
    await _flashcardSetsBox.put(flashcardSet.id, flashcardSet);
    if (folderId != null) {
      await assignContentToFolder(
          flashcardSet.id, folderId, 'flashcardSet', flashcardSet.userId);
    }
  }

  Future<void> saveFolder(Folder folder) async {
    await init();
    await _foldersBox.put(folder.id, folder);
  }

  Future<void> updateSummarySyncStatus(String id, bool isSynced) async {
    await init();
    final summary = _summariesBox.get(id);
    if (summary != null) {
      summary.isSynced = isSynced;
      await _summariesBox.put(id, summary);
    }
  }

  Future<void> updateQuizSyncStatus(String id, bool isSynced) async {
    await init();
    final quiz = _quizzesBox.get(id);
    if (quiz != null) {
      quiz.isSynced = isSynced;
      await _quizzesBox.put(id, quiz);
    }
  }

  Future<void> updateFlashcardSetSyncStatus(String id, bool isSynced) async {
    await init();
    final flashcardSet = _flashcardSetsBox.get(id);
    if (flashcardSet != null) {
      flashcardSet.isSynced = isSynced;
      await _flashcardSetsBox.put(id, flashcardSet);
    }
  }

  // --- GETTERS ---

  Future<LocalSummary?> getSummary(String id) async {
    await init();
    return _summariesBox.get(id);
  }

  Future<List<LocalSummary>> getAllSummaries(String userId) async {
    await init();
    return _summariesBox.values.where((s) => s.userId == userId).toList();
  }

  Future<LocalQuiz?> getQuiz(String id) async {
    await init();
    return _quizzesBox.get(id);
  }

  Future<List<LocalQuiz>> getAllQuizzes(String userId) async {
    await init();
    return _quizzesBox.values.where((q) => q.userId == userId).toList();
  }

  Future<LocalFlashcardSet?> getFlashcardSet(String id) async {
    await init();
    return _flashcardSetsBox.get(id);
  }

  Future<List<LocalFlashcardSet>> getAllFlashcardSets(String userId) async {
    await init();
    return _flashcardSetsBox.values
        .where((set) => set.userId == userId)
        .toList();
  }

  Future<List<LocalFlashcard>> getFlashcardsByIds(
      String userId, List<String> cardIds) async {
    await init();
    final sets = await getAllFlashcardSets(userId);
    final allCards = sets.expand((s) => s.flashcards).toList();
    return allCards.where((c) => cardIds.contains(c.id)).toList();
  }

  Future<Folder?> getFolder(String id) async {
    await init();
    return _foldersBox.get(id);
  }

  Future<List<Folder>> getAllFolders(String userId) async {
    await init();
    return _foldersBox.values
        .where((folder) => folder.userId == userId)
        .toList();
  }

  // --- DELETERS ---

  Future<void> _removeContentRelations(String contentId) async {
    final relations = _contentFoldersBox.values
        .where((cf) => cf.contentId == contentId)
        .toList();
    for (final relation in relations) {
      await _contentFoldersBox.delete(relation.key);
    }
  }

  Future<void> deleteSummary(String id) async {
    await init();
    await _removeContentRelations(id);
    await _summariesBox.delete(id);
  }

  Future<void> deleteQuiz(String id) async {
    await init();
    await _removeContentRelations(id);
    await _quizzesBox.delete(id);
  }

  Future<void> deleteFlashcardSet(String id) async {
    await init();
    await _removeContentRelations(id);
    await _flashcardSetsBox.delete(id);
  }

  Future<void> deleteFolder(String id) async {
    await init();
    final relations =
        _contentFoldersBox.values.where((cf) => cf.folderId == id).toList();
    for (final relation in relations) {
      await _contentFoldersBox.delete(relation.key);
    }
    await _foldersBox.delete(id);
  }

  // --- RELATIONSHIP MANAGEMENT ---

  Future<void> assignContentToFolder(String contentId, String folderId,
      String contentType, String userId) async {
    await init();
    final key = '$folderId-$contentId';
    final contentFolder = ContentFolder(
      contentId: contentId,
      folderId: folderId,
      contentType: contentType,
      userId: userId,
      assignedAt: DateTime.now(),
    );
    await _contentFoldersBox.put(key, contentFolder);
  }

  Future<List<ContentFolder>> getFolderContents(String folderId) async {
    await init();
    return _contentFoldersBox.values
        .where((cf) => cf.folderId == folderId)
        .toList();
  }

  // --- SPACED REPETITION & MISSIONS ---

  Box<SpacedRepetitionItem> getSpacedRepetitionBox() {
    return _spacedRepetitionBox;
  }

  Future<DailyMission?> getDailyMission(String id) async {
    await init();
    return _dailyMissionsBox.get(id);
  }

  Future<void> saveDailyMission(DailyMission mission) async {
    await init();
    await _dailyMissionsBox.put(mission.id, mission);
  }

  // --- OTHER ---

  Future<bool> isOfflineModeEnabled() async {
    await init();
    return _settingsBox.get('offlineMode', defaultValue: false);
  }

  Future<void> setOfflineMode(bool isEnabled) async {
    await init();
    await _settingsBox.put('offlineMode', isEnabled);
  }

  Future<void> clearAllData() async {
    await init();
    await _summariesBox.clear();
    await _quizzesBox.clear();
    await _flashcardSetsBox.clear();
    await _foldersBox.clear();
    await _contentFoldersBox.clear();
    await _settingsBox.clear();
    await _spacedRepetitionBox.clear();
    await _dailyMissionsBox.clear();
  }
}
