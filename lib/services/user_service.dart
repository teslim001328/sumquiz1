import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

import '../models/user_model.dart';
import '../services/time_sync_service.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Update user's daily goal
  Future<void> updateDailyGoal(String userId, int newGoal) async {
    await _db.collection('users').doc(userId).update({
      'dailyGoal': newGoal,
    });
  }

  /// Increment items completed today and update momentum/streak
  Future<void> incrementItemsCompleted(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    final user = UserModel.fromFirestore(userDoc);
    final now = DateTime.now();
    final lastUpdate = user.updatedAt ?? DateTime.now();

    // Check if it's a new day
    final isSameDay = now.year == lastUpdate.year &&
        now.month == lastUpdate.month &&
        now.day == lastUpdate.day;

    // Check for streak maintenance (yesterday check)
    final yesterday = now.subtract(const Duration(days: 1));
    final wasActiveYesterday = lastUpdate.year == yesterday.year &&
        lastUpdate.month == yesterday.month &&
        lastUpdate.day == yesterday.day;

    int newItemsCompleted = user.itemsCompletedToday;
    int newStreak = user.missionCompletionStreak;
    double newMomentum = user.currentMomentum;

    if (isSameDay) {
      newItemsCompleted++;
    } else {
      // New day: Apply momentum decay
      newMomentum = newMomentum * (1 - user.momentumDecayRate);

      // Streak maintenance: if not active today AND not active yesterday, reset streak
      if (!wasActiveYesterday && !isSameDay) {
        newStreak = 0;
      }

      newItemsCompleted = 1; // Reset for new day
    }

    // Momentum Gain: +5 per item (Pro gets 1.0x, Free gets 0.2x)
    double momentumGain = 5.0;
    if (!user.isPro) momentumGain *= 0.2;
    newMomentum += momentumGain;

    // Cap Momentum at 500 (standardized)
    if (newMomentum > 500) newMomentum = 500;

    // Streak increment: if it's the first item of the day
    if (newItemsCompleted == 1) {
      newStreak++;
    }

    await _db.collection('users').doc(userId).update({
      'itemsCompletedToday': newItemsCompleted,
      'missionCompletionStreak': newStreak,
      'currentMomentum': newMomentum,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    developer.log(
        'Progress updated for $userId: Streak=$newStreak, Momentum=${newMomentum.toStringAsFixed(1)}',
        name: 'UserService');
  }

  /// Reset daily progress (for testing or manual reset)
  Future<void> resetDailyProgress(String userId) async {
    await _db.collection('users').doc(userId).update({
      'itemsCompletedToday': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reset weekly uploads (should be called periodically)
  Future<void> resetWeeklyUploads(String userId) async {
    await _db.collection('users').doc(userId).update({
      'weeklyUploads': 0,
    });
  }

  /// Check if weekly uploads should be reset and reset if needed
  Future<void> checkAndResetWeeklyUploads(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final user = UserModel.fromFirestore(userDoc);
      final now = TimeSyncService.now;
      final lastReset = user.lastWeeklyReset ?? now;

      // Check if 7 days have passed since last reset
      if (now.difference(lastReset).inDays >= 7) {
        await _db.collection('users').doc(userId).update({
          'weeklyUploads': 0,
          'lastWeeklyReset': FieldValue.serverTimestamp(),
        });
        developer.log('Weekly usage reset for user: $userId',
            name: 'UserService');
      }
    } catch (e) {
      developer.log('Error checking weekly reset: $e', name: 'UserService');
    }
  }

  /// Upgrade user to Pro
  Future<void> upgradeToPro(String userId, {Duration? duration}) async {
    final expiryDate = duration != null ? DateTime.now().add(duration) : null;

    // If upgrading to Lifetime, expiryDate could be set to distant future or handled by logic
    // For now we'll just set it. Null might imply Lifetime in some logic, or we need a specific flag.
    // UserModel uses expiry date check for 'isPro'.

    final Map<String, dynamic> updateData = {
      'subscriptionExpiry':
          expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      // Ensure we might want a field like 'isLifetime' if duration is null/infinite
    };

    // If lifetime (no duration passed, or special handling)
    // Let's assume for this specific implementation, if duration is NULL it is NOT lifetime, but just "indefinite" or handled elsewhere.
    // But typically payments have specific durations.
    // Let's just update the expiry.

    await _db.collection('users').doc(userId).update(updateData);
    developer.log('User $userId upgraded to Pro until $expiryDate',
        name: 'UserService');
  }
}
