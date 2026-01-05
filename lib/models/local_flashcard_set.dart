import 'package:hive/hive.dart';
import 'local_flashcard.dart';

part 'local_flashcard_set.g.dart';

@HiveType(typeId: 4)
class LocalFlashcardSet extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late List<LocalFlashcard> flashcards;

  @HiveField(3)
  late DateTime timestamp;

  @HiveField(4)
  late bool isSynced;

  @HiveField(5)
  late String userId;

  @HiveField(6)
  late bool isReadOnly;

  @HiveField(7)
  String? publicDeckId;

  @HiveField(8)
  String? creatorName;

  LocalFlashcardSet({
    required this.id,
    required this.title,
    required this.flashcards,
    required this.timestamp,
    this.isSynced = false,
    required this.userId,
    this.isReadOnly = false,
    this.publicDeckId,
    this.creatorName,
  });

  LocalFlashcardSet.empty() {
    id = '';
    title = '';
    flashcards = [];
    timestamp = DateTime.now();
    isSynced = false;
    userId = '';
    isReadOnly = false;
    publicDeckId = null;
    creatorName = null;
  }
}
