import 'package:cloud_firestore/cloud_firestore.dart';

import '../flashcard_set.dart';
import '../local_flashcard_set.dart';
import 'local_flashcard_extension.dart';

extension LocalFlashcardSetExtension on LocalFlashcardSet {
  FlashcardSet toFlashcardSet() {
    return FlashcardSet(
      id: id,
      title: title,
      flashcards: flashcards.map((e) => e.toFlashcard()).toList(),
      timestamp: Timestamp.fromDate(timestamp),
    );
  }
}
