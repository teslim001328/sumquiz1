import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/models/summary_model.dart';
import 'package:sumquiz/models/quiz_model.dart';
import 'package:sumquiz/models/flashcard_set.dart';
import 'package:sumquiz/models/editable_content.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';

enum LibraryItemType { summary, quiz, flashcards }

class LibraryItem {
  final String id;
  final String title;
  final LibraryItemType type;
  final Timestamp timestamp;
  final bool isReadOnly;

  LibraryItem({
    required this.id,
    required this.title,
    required this.type,
    required this.timestamp,
    this.isReadOnly = false,
  });

  factory LibraryItem.fromSummary(Summary summary) {
    return LibraryItem(
      id: summary.id,
      title: summary.content,
      type: LibraryItemType.summary,
      timestamp: summary.timestamp,
      isReadOnly: false,
    );
  }

  factory LibraryItem.fromQuiz(Quiz quiz) {
    return LibraryItem(
      id: quiz.id,
      title: quiz.title,
      type: LibraryItemType.quiz,
      timestamp: quiz.timestamp,
      isReadOnly: false,
    );
  }

  factory LibraryItem.fromFlashcardSet(FlashcardSet flashcardSet) {
    return LibraryItem(
      id: flashcardSet.id,
      title: flashcardSet.title,
      type: LibraryItemType.flashcards,
      timestamp: flashcardSet.timestamp,
      isReadOnly: false,
    );
  }

  factory LibraryItem.fromLocalSummary(LocalSummary summary) {
    return LibraryItem(
      id: summary.id,
      title: summary.title,
      type: LibraryItemType.summary,
      timestamp: Timestamp.fromDate(summary.timestamp),
    );
  }

  factory LibraryItem.fromLocalQuiz(LocalQuiz quiz) {
    return LibraryItem(
      id: quiz.id,
      title: quiz.title,
      type: LibraryItemType.quiz,
      timestamp: Timestamp.fromDate(quiz.timestamp),
    );
  }

  factory LibraryItem.fromLocalFlashcardSet(LocalFlashcardSet flashcardSet) {
    return LibraryItem(
      id: flashcardSet.id,
      title: flashcardSet.title,
      type: LibraryItemType.flashcards,
      timestamp: Timestamp.fromDate(flashcardSet.timestamp),
    );
  }

  EditableContent toEditableContent() {
    return EditableContent(
        id: id,
        title: title,
        type: type.name,
        content: '' // This should be populated with the actual content
        ,
        timestamp: timestamp);
  }
}
