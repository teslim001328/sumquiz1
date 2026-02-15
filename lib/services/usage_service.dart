import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/referral_service.dart';
import 'package:sumquiz/services/notification_service.dart';
import 'package:sumquiz/services/notification_manager.dart';
import 'package:sumquiz/services/local_database_service.dart';

class UsageConfig {
  static const int freeDecksPerDay =
      2; // "1-2 decks/day" -> 2 for user friendliness
  static const int trialDecksPerDay = 3; // "3-5 decks/day" -> 3 for trial
  static const int proDecksPerDay = 100; // "Unlimited or high cap"
}

class UsageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ReferralService _referralService = ReferralService();

  /// Check if user can generate a deck
  Future<bool> canGenerateDeck(String uid) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return true; // Fail safe

      final user = UserModel.fromFirestore(userDoc);

      // Check daily reset
      final now = DateTime.now();
      final lastGen = user.lastDeckGenerationDate;
      bool isNewDay = lastGen == null ||
          now.year != lastGen.year ||
          now.month != lastGen.month ||
          now.day != lastGen.day;

      int currentUsage = isNewDay ? 0 : user.dailyDecksGenerated;

      // Determine limit based on user tier
      int limit = UsageConfig.freeDecksPerDay;

      if (user.isCreatorPro) {
        // Creator Pro: Unlimited (high cap)
        limit = UsageConfig.proDecksPerDay;
      } else if (user.isPro) {
        // Pro user: Check if trial or paid
        if (user.isTrial) {
          limit = UsageConfig.trialDecksPerDay; // 3 decks/day
        } else {
          limit = UsageConfig.proDecksPerDay; // 100 decks/day
        }
      }

      final canGenerate = currentUsage < limit;

      // 🔔 Schedule Pro upgrade notification if limit reached
      if (!canGenerate && !user.isPro) {
        try {
          final notificationService = NotificationService();
          final localDb = LocalDatabaseService();
          final manager = NotificationManager(notificationService, localDb);
          await manager.scheduleProUpgradeReminder();
          developer.log('Pro upgrade notification scheduled',
              name: 'UsageService');
        } catch (e) {
          developer.log('Failed to schedule Pro upgrade notification',
              name: 'UsageService', error: e);
        }
      }

      return canGenerate;
    } catch (e, s) {
      developer.log('Error checking usage limit',
          name: 'UsageService', error: e, stackTrace: s);
      return false;
    }
  }

  /// Record a deck generation
  Future<void> recordDeckGeneration(String uid) async {
    try {
      // Run transaction and return referrerId (if any) to reward
      String? referrerIdToReward =
          await _db.runTransaction<String?>((transaction) async {
        final userRef = _db.collection('users').doc(uid);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) return null;
        final user = UserModel.fromFirestore(userDoc);

        final now = DateTime.now();
        final lastGen = user.lastDeckGenerationDate;
        bool isNewDay = lastGen == null ||
            now.year != lastGen.year ||
            now.month != lastGen.month ||
            now.day != lastGen.day;

        int newDailyCount = isNewDay ? 1 : user.dailyDecksGenerated + 1;
        int newTotalCount = user.totalDecksGenerated + 1;

        // Check for weekly reset (7 days since last reset)
        final lastWeeklyReset = user.lastWeeklyReset;
        bool isNewWeek = lastWeeklyReset == null ||
            now.difference(lastWeeklyReset).inDays >= 7;

        int newTotalUploads = user.totalUploads + 1;
        int newWeeklyUploads = isNewWeek ? 1 : user.weeklyUploads + 1;

        transaction.update(userRef, {
          'dailyDecksGenerated': newDailyCount,
          'totalDecksGenerated': newTotalCount,
          'totalUploads': newTotalUploads,
          'weeklyUploads': newWeeklyUploads,
          'lastDeckGenerationDate': FieldValue.serverTimestamp(),
          if (isNewWeek) 'lastWeeklyReset': FieldValue.serverTimestamp(),
        });

        // REFERRAL TRIGGER: "Referrer bonus activates after invitee generates 1 deck"
        if (newTotalCount == 1) {
          // This is their FIRST deck
          final data = userDoc.data() as Map<String, dynamic>;
          if (data.containsKey('referredBy')) {
            return data['referredBy'] as String?;
          }
        }
        return null;
      });

      // Grant reward outside the user transaction to ensure atomicity of that specific update
      if (referrerIdToReward != null) {
        await _referralService.grantReferrerReward(referrerIdToReward);
      }
    } catch (e, s) {
      developer.log('Error recording action',
          name: 'UsageService', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Record a general action (linked to same daily limit for now)
  Future<void> recordAction(String uid, String action) async {
    await recordDeckGeneration(uid);
  }

  /// Check if user can perform an action (checks daily deck limit)
  Future<bool> canPerformAction(String uid, String action) async {
    return await canGenerateDeck(uid);
  }
}
