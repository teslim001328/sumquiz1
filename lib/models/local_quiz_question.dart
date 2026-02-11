import 'package:hive/hive.dart';

part 'local_quiz_question.g.dart';

@HiveType(typeId: 2)
class LocalQuizQuestion extends HiveObject {
  @HiveField(0)
  late String question;

  @HiveField(1)
  late List<String> options;

  @HiveField(2)
  late String correctAnswer;

  @HiveField(3)
  String? explanation;

  @HiveField(4)
  String? questionType;

  LocalQuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.questionType,
  });

  factory LocalQuizQuestion.fromJson(Map<String, dynamic> json) =>
      LocalQuizQuestion(
        question: json['question'] ?? '',
        options: List<String>.from(json['options'] ?? []),
        correctAnswer: json['correctAnswer'] ?? '',
        explanation: json['explanation'],
        questionType: json['questionType'],
      );

  LocalQuizQuestion.empty() {
    question = '';
    options = [];
    correctAnswer = '';
    explanation = null;
    questionType = null;
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'questionType': questionType,
    };
  }
}
