import 'package:hive/hive.dart';
import 'local_quiz_question.dart';

part 'local_quiz.g.dart';

@HiveType(typeId: 1)
class LocalQuiz extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late List<LocalQuizQuestion> questions;

  @HiveField(3)
  late DateTime timestamp;

  @HiveField(4)
  late bool isSynced;

  @HiveField(5)
  late String userId;

  @HiveField(6)
  late List<double> scores;

  @HiveField(7)
  late bool isReadOnly;

  @HiveField(8)
  String? publicDeckId;

  @HiveField(9)
  String? creatorName;

  @HiveField(10)
  late int timeSpent; // In seconds

  LocalQuiz({
    required this.id,
    required this.title,
    required this.questions,
    required this.timestamp,
    this.isSynced = false,
    required this.userId,
    List<double>? scores,
    this.isReadOnly = false,
    this.publicDeckId,
    this.creatorName,
    this.timeSpent = 0,
  }) : scores = scores ?? [];

  double? get score => scores.isNotEmpty ? scores.last : null;

  LocalQuiz.empty() {
    id = '';
    title = '';
    questions = [];
    timestamp = DateTime.now();
    isSynced = false;
    userId = '';
    scores = [];
    isReadOnly = false;
    publicDeckId = null;
    creatorName = null;
    timeSpent = 0;
  }
}
