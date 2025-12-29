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

  LocalQuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  factory LocalQuizQuestion.fromJson(Map<String, dynamic> json) =>
      LocalQuizQuestion(
        question: json['question'] ?? '',
        options: List<String>.from(json['options'] ?? []),
        correctAnswer: json['correctAnswer'] ?? '',
      );

  LocalQuizQuestion.empty() {
    question = '';
    options = [];
    correctAnswer = '';
  }
}
