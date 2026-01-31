import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/daily_mission.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'local_database_service.dart';
import 'spaced_repetition_service.dart';
import 'notification_service.dart';

class MissionService {
  final FirestoreService _firestoreService;
  final LocalDatabaseService _localDb;
  final SpacedRepetitionService _srs;
  final NotificationService? _notificationService;

  MissionService({
    required FirestoreService firestoreService,
    required LocalDatabaseService localDb,
    required SpacedRepetitionService srs,
    NotificationService? notificationService,
  })  : _firestoreService = firestoreService,
        _localDb = localDb,
        _srs = srs,
        _notificationService = notificationService;

  String _getMissionId(DateTime date) {
    return 'mission_${date.year}-${date.month}-${date.day}';
  }

  Future<DailyMission> generateDailyMission(String userId) async {
    final now = DateTime.now();
    final missionId = _getMissionId(now);

    // 1. Check if mission already exists for today
    final existingMission = await _localDb.getDailyMission(missionId);
    if (existingMission != null) {
      return existingMission;
    }

    // 2. Fetch User Data for Difficulty/Momentum
    UserModel? user;
    try {
      user = await _firestoreService.streamUser(userId).first;
    } catch (e) {
      debugPrint('Error fetching user for mission generation: $e');
    }

    // Default to Level 3 (Standard) if user not found or error
    final difficulty = user?.difficultyPreference ?? 3;

    // 3. Adaptive Content Selection
    final dueCardIds = await _srs.getDueFlashcardIds(userId);
    List<String> selectedFlashcards = [];
    int estimatedMinutes = 0;
    int momentumReward = 100; // Base

    if (difficulty <= 1) {
      // Light Load: 5 Due Cards max
      selectedFlashcards = dueCardIds.take(5).toList();
      estimatedMinutes = 2;
      momentumReward = 50;
    } else if (difficulty >= 5) {
      // Heavy Load: 15 Due Cards + 5 Weak (simulated by taking more due for now)
      // MVP: Just take more due cards
      selectedFlashcards = dueCardIds.take(20).toList();
      estimatedMinutes = 12;
      momentumReward = 150;
    } else {
      // Standard (Level 3): 10 Due Cards
      selectedFlashcards = dueCardIds.take(10).toList();
      estimatedMinutes = 6;
      momentumReward = 100;
    }

    // If we don't have enough due cards, we should potentially fetch random ones from Library
    // For MVP, we'll just use what we have, even if it's 0.
    // Ideally, we'd fetch random non-due cards to fill the quota.

    final mission = DailyMission(
      id: missionId,
      date: now,
      flashcardIds: selectedFlashcards,
      isCompleted: false,
      estimatedTimeMinutes: estimatedMinutes,
      momentumReward: momentumReward,
      difficultyLevel: difficulty,
      completionScore: 0.0,
      miniQuizTopic: null, // MVP: No quiz yet
    );

    // 4. Save
    await _localDb.saveDailyMission(mission);

    // 5. Schedule Priming Notification (30m before preferred time)
    if (_notificationService != null && user != null) {
      try {
        await _notificationService.schedulePrimingNotification(
          userId: userId,
          preferredStudyTime: user.preferredStudyTime,
          cardCount: mission.flashcardIds.length,
          estimatedMinutes: mission.estimatedTimeMinutes,
        );
      } catch (e) {
        debugPrint('Error scheduling priming notification: $e');
      }
    }

    return mission;
  }

  Future<void> completeMission(
      String userId, DailyMission mission, double score) async {
    if (mission.isCompleted) return;

    // Check if user is Pro to determine reward eligibility
    final isPro = await _isUserPro(userId);

    mission.isCompleted = true;
    mission.completionScore = score;
    await mission.save(); // Hive save

    // Update User Momentum (only for Pro users)
    if (isPro) {
      try {
        final userSnapshot =
            await _firestoreService.db.collection('users').doc(userId).get();
        if (!userSnapshot.exists) return;

        final user = UserModel.fromFirestore(userSnapshot);

        // 1. Apply Decay
        double newMomentum =
            user.currentMomentum * (1 - user.momentumDecayRate);

        // 2. Calculate Daily Gain
        int baseReward =
            mission.momentumReward; // From mission (100, 150, etc.)

        // Difficulty Bonus
        double difficultyBonus = 1.0;
        if (mission.difficultyLevel >= 5) {
          difficultyBonus = 1.2;
        } else if (mission.difficultyLevel >= 3) {
          difficultyBonus = 1.1;
        }

        // Streak Multiplier
        double streakMult = 1.0 + (user.missionCompletionStreak * 0.05);
        if (streakMult > 1.5) streakMult = 1.5; // Cap at 1.5x

        // Accuracy Penalty/Bonus
        double accuracyMult = score; // 0.0 to 1.0
        if (accuracyMult < 0.5) {
          accuracyMult = 0.5; // Minimum 50% reward even if poor
        }

        double dailyGain =
            baseReward * difficultyBonus * streakMult * accuracyMult;
        if (dailyGain > 300) dailyGain = 300; // Cap daily gain

        newMomentum += dailyGain;

        // 3. Cap Total Momentum
        if (newMomentum > 1000)
          newMomentum = 1000; // Increased cap for more growth

        // 4. Save to Firestore
        final updatedUser = user.copyWith(
          currentMomentum: newMomentum,
          // Streak is now handled by incrementItemsCompleted
        );
        await _firestoreService.saveUserData(updatedUser);

        debugPrint(
            'Mission completed! Momentum: ${user.currentMomentum} -> $newMomentum (+${dailyGain.toStringAsFixed(0)})');

        // 6. Schedule Recall Notification (20h from now)
        if (_notificationService != null) {
          try {
            // 🚫 Cancel streak saver notification for today
            await _notificationService.cancelNotification(1003);

            await _notificationService.scheduleRecallNotification(
              momentumGain: dailyGain.round(),
            );
          } catch (e) {
            debugPrint('Error scheduling recall notification: $e');
          }
        }
      } catch (e) {
        debugPrint('Error updating momentum: $e');
      }
    } else {
      debugPrint('Mission completed but no rewards for FREE tier user');

      // Still update streak for FREE users but no momentum gain
      try {
        final userSnapshot =
            await _firestoreService.db.collection('users').doc(userId).get();
        if (!userSnapshot.exists) return;

        final user = UserModel.fromFirestore(userSnapshot);

        // Update streak only
        int newStreak = user.missionCompletionStreak + 1;

        final updatedUser = user.copyWith(
          missionCompletionStreak: newStreak,
        );
        await _firestoreService.saveUserData(updatedUser);
      } catch (e) {
        debugPrint('Error updating streak for FREE user: $e');
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
}
