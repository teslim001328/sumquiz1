import 'package:flutter/widgets.dart'; // Import for WidgetsBinding
import 'package:collection/collection.dart';

import '../../models/local_quiz.dart';
import '../../services/local_database_service.dart';
import '../../services/auth_service.dart';

class QuizViewModel with ChangeNotifier {
  final LocalDatabaseService _localDatabaseService;
  final AuthService _authService;

  List<LocalQuiz> _quizzes = [];
  bool _isLoading = false;

  QuizViewModel(this._localDatabaseService, this._authService);

  List<LocalQuiz> get quizzes => _quizzes;
  bool get isLoading => _isLoading;

  int get quizzesTaken {
    if (_quizzes.isEmpty) return 0;
    return _quizzes.map((q) => q.scores.length).sum;
  }

  double get averageScore {
    if (_quizzes.isEmpty) return 0.0;
    final allScores = _quizzes.expand((q) => q.scores).toList();
    if (allScores.isEmpty) return 0.0;
    return allScores.average;
  }

  double get bestScore {
    if (_quizzes.isEmpty) return 0.0;
    final allScores = _quizzes.expand((q) => q.scores).toList();
    if (allScores.isEmpty) return 0.0;
    return allScores.reduce((max, score) => score > max ? score : max);
  }

  Future<void> _loadQuizzes(String userId) async {
    _setLoading(true);
    await _localDatabaseService.init();
    _quizzes = await _localDatabaseService.getAllQuizzes(userId);
    _setLoading(false);
  }

  void _setLoading(bool loading) {
    if (_isLoading == loading) return;
    _isLoading = loading;
    // Ensure listeners are notified safely after the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ChangeNotifier.debugAssertNotDisposed(this)) {
        // Add safety check
        notifyListeners();
      }
    });
  }

  Future<void> initializeForUser(String userId) async {
    await _loadQuizzes(userId);
  }

  Future<void> refresh() async {
    final user = _authService.currentUser;
    if (user != null) {
      await _loadQuizzes(user.uid);
    }
  }
}
