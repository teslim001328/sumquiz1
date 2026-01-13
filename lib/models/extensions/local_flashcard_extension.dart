import '../flashcard.dart';
import '../local_flashcard.dart';

extension LocalFlashcardExtension on LocalFlashcard {
  Flashcard toFlashcard() {
    return Flashcard(
      id: id,
      question: question,
      answer: answer,
    );
  }
}
