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
  final String? creatorName;
  final int? itemCount; // e.g., number of flashcards
  final double? score; // e.g., quiz score
  final String? description;

  LibraryItem({
    required this.id,
    required this.title,
    required this.type,
    required this.timestamp,
    this.isReadOnly = false,
    this.creatorName,
    this.itemCount,
    this.score,
    this.description,
  });

  factory LibraryItem.fromSummary(Summary summary) {
    return LibraryItem(
      id: summary.id,
      title: summary.content, // Note: mobile uses content as title sometimes
      type: LibraryItemType.summary,
      timestamp: summary.timestamp,
      isReadOnly: false,
      description: summary.description,
    );
  }

  factory LibraryItem.fromQuiz(Quiz quiz) {
    return LibraryItem(
      id: quiz.id,
      title: quiz.title,
      type: LibraryItemType.quiz,
      timestamp: quiz.timestamp,
      isReadOnly: false,
      itemCount: quiz.questions.length,
    );
  }

  factory LibraryItem.fromFlashcardSet(FlashcardSet flashcardSet) {
    return LibraryItem(
      id: flashcardSet.id,
      title: flashcardSet.title,
      type: LibraryItemType.flashcards,
      timestamp: flashcardSet.timestamp,
      isReadOnly: false,
      itemCount: flashcardSet.flashcards.length,
    );
  }

  factory LibraryItem.fromLocalSummary(LocalSummary summary) {
    return LibraryItem(
      id: summary.id,
      title: summary.title,
      type: LibraryItemType.summary,
      timestamp: Timestamp.fromDate(summary.timestamp),
      creatorName: summary.creatorName,
      description: summary.description,
    );
  }

  factory LibraryItem.fromLocalQuiz(LocalQuiz quiz) {
    return LibraryItem(
      id: quiz.id,
      title: quiz.title,
      type: LibraryItemType.quiz,
      timestamp: Timestamp.fromDate(quiz.timestamp),
      creatorName: quiz.creatorName,
      itemCount: quiz.questions.length,
      score: quiz.score,
    );
  }

  factory LibraryItem.fromLocalFlashcardSet(LocalFlashcardSet flashcardSet) {
    return LibraryItem(
      id: flashcardSet.id,
      title: flashcardSet.title,
      type: LibraryItemType.flashcards,
      timestamp: Timestamp.fromDate(flashcardSet.timestamp),
      creatorName: flashcardSet.creatorName,
      itemCount: flashcardSet.flashcards.length,
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
