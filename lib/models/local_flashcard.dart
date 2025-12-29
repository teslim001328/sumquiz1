import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'local_flashcard.g.dart';

@HiveType(typeId: 3)
class LocalFlashcard extends HiveObject {
  @HiveField(0)
  late String question;

  @HiveField(1)
  late String answer;

  @HiveField(2)
  late String id;

  LocalFlashcard({
    required this.question,
    required this.answer,
  }) : id = const Uuid().v4();

  factory LocalFlashcard.fromJson(Map<String, dynamic> json) => LocalFlashcard(
        question: json['question'] ?? '',
        answer: json['answer'] ?? '',
      );

  LocalFlashcard.empty() {
    question = '';
    answer = '';
    id = const Uuid().v4();
  }
}
