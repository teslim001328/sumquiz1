import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';

import '../models/spaced_repetition.dart';
import '../models/local_flashcard.dart';
import 'dart:developer' as developer;

class SpacedRepetitionService {
  final Box<SpacedRepetitionItem> _box;
  static const int freeSrsCardsMax = 50;

  SpacedRepetitionService(this._box);

  Future<void> scheduleReview(String flashcardId, String userId) async {
    // Check SRS card limit for FREE tier users
    final isPro = await _isUserPro(userId);
    if (!isPro) {
      final currentCardCount = await _getCurrentSrsCardCount(userId);
      if (currentCardCount >= freeSrsCardsMax) {
        throw Exception(
            'SRS card limit reached. Upgrade to Pro for unlimited cards.');
      }
    }

    final now = DateTime.now().toUtc();
    final newItem = SpacedRepetitionItem(
      id: flashcardId, // Use flashcardId as the key
      userId: userId,
      contentId: flashcardId,
      contentType: 'flashcards',
      nextReviewDate: now,
      lastReviewed: now,
      createdAt: now,
      updatedAt: now,
    );
    // Store using flashcardId so we can easily retrieve it later
    await _box.put(flashcardId, newItem);

    // Update SRS card count for FREE tier users
    if (!isPro) {
      try {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);
        await userDoc.update({
          'srsCardCount': FieldValue.increment(1),
        });
      } catch (e, s) {
        // Log error but don't fail the operation
        developer.log('Error updating SRS card count',
            name: 'SpacedRepetitionService', error: e, stackTrace: s);
      }
    }
  }

  /// Check if user has Pro access
  Future<bool> _isUserPro(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      // Check for 'subscriptionExpiry' field
      if (data.containsKey('subscriptionExpiry')) {
        // Lifetime access is handled by a null expiry date
        if (data['subscriptionExpiry'] == null) return true;

        final expiryDate = (data['subscriptionExpiry'] as Timestamp).toDate();
        return expiryDate.isAfter(DateTime.now());
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get current SRS card count for user
  Future<int> _getCurrentSrsCardCount(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists) return 0;

      final data = doc.data();
      if (data == null) return 0;

      return data['srsCardCount'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> updateReview(String itemId, bool answeredCorrectly) async {
    // The itemId passed here is typically the flashcardId.
    // We first try to get it directly (new behavior).
    var item = _box.get(itemId);

    // Fallback: If not found, check if it was stored with a UUID (legacy behavior).
    item ??= _box.values.firstWhereOrNull((i) => i.contentId == itemId);

    if (item == null) return;

    final now = DateTime.now().toUtc();
    int repetitionCount;
    double easeFactor;
    int interval;
    int correctStreak;

    if (answeredCorrectly) {
      correctStreak = item.correctStreak + 1;
      repetitionCount = item.repetitionCount + 1;
      easeFactor = item.easeFactor + (0.1 - (5 - 4) * (0.08 + (5 - 4) * 0.02));
      if (easeFactor < 1.3) easeFactor = 1.3;

      if (repetitionCount == 1) {
        interval = 1;
      } else if (repetitionCount == 2) {
        interval = 6;
      } else {
        interval = (item.interval * easeFactor).round();
      }
    } else {
      correctStreak = 0;
      repetitionCount = 0; // Reset repetition count
      interval = 1; // Review again tomorrow
      easeFactor =
          item.easeFactor; // E-factor does not change on incorrect answer
    }

    final updatedItem = SpacedRepetitionItem(
      id: item.id, // Preserve the existing ID (whether UUID or flashcardId)
      userId: item.userId,
      contentId: item.contentId,
      contentType: item.contentType,
      nextReviewDate: now.add(Duration(days: interval)),
      lastReviewed: now,
      createdAt: item.createdAt,
      updatedAt: now,
      interval: interval,
      easeFactor: easeFactor,
      repetitionCount: repetitionCount,
      correctStreak: correctStreak,
    );

    // Save back using the SAME key we retrieved it with
    await _box.put(item.id, updatedItem);
  }

  Future<List<String>> getDueFlashcardIds(String userId) async {
    final now = DateTime.now().toUtc();
    return _box.values
        .where((item) =>
            item.userId == userId &&
            item.contentType == 'flashcards' &&
            item.nextReviewDate.isBefore(now))
        .map((item) => item.contentId)
        .toList();
  }

  Future<List<LocalFlashcard>> getDueFlashcards(
      String userId, List<LocalFlashcard> allFlashcards) async {
    final dueItemIds = await getDueFlashcardIds(userId);
    final dueItemIdsSet = dueItemIds.toSet();

    return allFlashcards
        .where((flashcard) => dueItemIdsSet.contains(flashcard.id))
        .toList();
  }

  Future<Map<String, dynamic>> getStatistics(String userId) async {
    final now = DateTime.now().toUtc();
    final startOfToday = DateTime.utc(now.year, now.month, now.day);
    final endOfWeek = startOfToday.add(const Duration(days: 7));

    final userItems =
        _box.values.where((item) => item.userId == userId).toList();

    final dueForReviewCount =
        userItems.where((item) => item.nextReviewDate.isBefore(now)).length;

    final upcomingReviews = userItems
        .where((item) =>
            item.nextReviewDate.isAfter(startOfToday) &&
            item.nextReviewDate.isBefore(endOfWeek))
        .groupListsBy((item) => DateTime.utc(item.nextReviewDate.year,
            item.nextReviewDate.month, item.nextReviewDate.day))
        .entries
        .map((entry) => MapEntry(entry.key, entry.value.length))
        .sortedBy<DateTime>((entry) => entry.key)
        .toList();

    return {
      'dueForReviewCount': dueForReviewCount,
      'upcomingReviews': upcomingReviews,
    };
  }

  /// Get the date of the very next review due (after now)
  DateTime? getNextReviewDate(String userId) {
    final now = DateTime.now().toUtc();
    final userItems =
        _box.values.where((item) => item.userId == userId).toList();

    if (userItems.isEmpty) return null;

    final futureReviews = userItems
        .where((item) => item.nextReviewDate.isAfter(now))
        .map((item) => item.nextReviewDate)
        .toList();

    if (futureReviews.isEmpty) return null;

    return futureReviews.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Calculate mastery score (0-100) based on SRS proficiency
  double getMasteryScore(String userId) {
    final userItems =
        _box.values.where((item) => item.userId == userId).toList();
    if (userItems.isEmpty) return 0.0;

    // Weight correct streak and ease factor
    double totalMastery = 0.0;
    for (var item in userItems) {
      double itemMastery = (item.correctStreak * 10) + (item.easeFactor * 10);
      if (itemMastery > 100) itemMastery = 100;
      totalMastery += itemMastery;
    }

    return totalMastery / userItems.length;
  }
}
