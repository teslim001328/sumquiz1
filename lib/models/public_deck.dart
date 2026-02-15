import 'package:cloud_firestore/cloud_firestore.dart';

class PublicDeck {
  final String id;
  final String creatorId;
  final String creatorName;
  final String title;
  final String description;
  final String shareCode;
  final Map<String, dynamic> summaryData;
  final Map<String, dynamic> quizData;
  final Map<String, dynamic> flashcardData;
  final int startedCount;
  final int completedCount;
  final DateTime publishedAt;

  PublicDeck({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.description,
    required this.shareCode,
    required this.summaryData,
    required this.quizData,
    required this.flashcardData,
    this.startedCount = 0,
    this.completedCount = 0,
    required this.publishedAt,
  });

  factory PublicDeck.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PublicDeck(
      id: doc.id,
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      shareCode: data['shareCode'] ?? '',
      summaryData: data['summary'] ?? {},
      quizData: data['quiz'] ?? {},
      flashcardData: data['flashcards'] ?? {},
      startedCount: data['startedCount'] ?? 0,
      completedCount: data['completedCount'] ?? 0,
      publishedAt:
          (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'title': title,
      'description': description,
      'shareCode': shareCode,
      'summary': summaryData,
      'quiz': quizData,
      'flashcards': flashcardData, // Add shareCode here
      'startedCount': startedCount,
      'completedCount': completedCount,
      'publishedAt': Timestamp.fromDate(publishedAt),
    };
  }
}
