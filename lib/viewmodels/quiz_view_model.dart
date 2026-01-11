import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'dart:developer' as developer;

class QuizViewModel extends ChangeNotifier {
  final LocalDatabaseService _localDbService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  List<LocalQuiz> _quizzes = [];
  List<LocalQuiz> get quizzes => _quizzes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  QuizViewModel({required LocalDatabaseService localDbService})
      : _localDbService = localDbService;

  // This will be called by the LibraryScreen when the user changes.
  void initializeForUser(String? userId) {
    if (_userId == userId && _quizzes.isNotEmpty) {
      return; // Avoid unnecessary reloads
    }
    _userId = userId;
    if (_userId != null) {
      refreshQuizzes();
    } else {
      _quizzes = [];
      notifyListeners();
    }
  }

  /// Fetches quizzes from both local DB and Firestore, then merges them.
  Future<void> refreshQuizzes() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch from local database (the primary source of truth)
      final localQuizzes = await _localDbService.getAllQuizzes(_userId!);

      // 2. Fetch from Firestore (for legacy/synced quizzes not yet in local DB)
      List<LocalQuiz> firestoreQuizzes = [];
      try {
        final snapshot = await _firestore
            .collection('quizzes')
            .where('userId', isEqualTo: _userId)
            .get();

        firestoreQuizzes = snapshot.docs.map((doc) {
          final data = doc.data();
          // Create a lightweight LocalQuiz object from Firestore data
          return LocalQuiz(
            id: doc.id,
            title: data['title'] ?? 'Untitled Quiz',
            scores: List<double>.from(data['scores'] ?? []),
            questions: const [], // Questions aren't needed for the library list view
            userId: data['userId'] ?? '',
            timestamp:
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isSynced: true, // Data from Firestore is considered synced
          );
        }).toList();
      } catch (e) {
        developer.log(
            'Could not fetch quizzes from Firestore. This may be normal if offline.',
            name: 'QuizViewModel',
            error: e);
        // Proceed with local quizzes even if Firestore fails
      }

      // 3. Merge the two lists, prioritizing local data
      final Map<String, LocalQuiz> combinedQuizzes = {};

      // Add all local quizzes first. They are the most up-to-date.
      for (final quiz in localQuizzes) {
        combinedQuizzes[quiz.id] = quiz;
      }

      // Add quizzes from Firestore only if they haven't already been loaded from the local DB.
      for (final quiz in firestoreQuizzes) {
        combinedQuizzes.putIfAbsent(quiz.id, () => quiz);
      }

      // 4. Update the final list and sort it with the newest quizzes first
      _quizzes = combinedQuizzes.values.toList();
      _quizzes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      developer.log('An error occurred while refreshing quizzes.',
          name: 'QuizViewModel', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- STATS CALCULATION ---

  double get averageScore {
    if (_quizzes.isEmpty) return 0.0;
    final allScores = _quizzes.expand((quiz) => quiz.scores).toList();
    if (allScores.isEmpty) return 0.0;
    return allScores.reduce((a, b) => a + b) / allScores.length;
  }

  int get totalQuizzesTaken {
    return _quizzes.fold(0, (sum, quiz) => sum + quiz.scores.length);
  }

  // Note: This requires question data. For full accuracy, this should be calculated
  // on a screen where the full quiz data is loaded.
  int get totalPerfectScores {
    return _quizzes.fold(0, (sum, quiz) {
      if (quiz.questions.isEmpty) {
        return sum; // Cannot determine if questions are not loaded
      }
      final perfectScores =
          quiz.scores.where((score) => score == quiz.questions.length).length;
      return sum + perfectScores;
    });
  }
}
