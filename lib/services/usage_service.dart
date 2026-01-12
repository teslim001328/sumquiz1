import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/referral_service.dart';

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

      // Infinite Pro Check
      if (user.isPro && user.subscriptionExpiry == null) return true;

      // Check daily reset
      final now = DateTime.now();
      final lastGen = user.lastDeckGenerationDate;
      bool isNewDay = lastGen == null ||
          now.year != lastGen.year ||
          now.month != lastGen.month ||
          now.day != lastGen.day;

      int currentUsage = isNewDay ? 0 : user.dailyDecksGenerated;

      int limit = UsageConfig.freeDecksPerDay;

      // 1. Creator Bonus or Lifetime/Paid Pro (non-trial) gets high limit
      if (user.isCreatorPro) {
        limit = UsageConfig.proDecksPerDay;
      } else if (user.isPro) {
        // 2. Trial Pro check
        if (user.isTrial) {
          limit = UsageConfig.trialDecksPerDay; // 3 decks per day
        } else {
          limit = UsageConfig.proDecksPerDay; // 100 decks per day (Paid)
        }
      }

      return currentUsage < limit;
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

        transaction.update(userRef, {
          'dailyDecksGenerated': newDailyCount,
          'totalDecksGenerated': newTotalCount,
          'lastDeckGenerationDate': FieldValue.serverTimestamp(),
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
      await _referralService.grantReferrerReward(referrerIdToReward);
        } catch (e, s) {
      developer.log('Error recording action',
          name: 'UsageService', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Record a general action (legacy, for other limits)
  Future<void> recordAction(String action) async {
    // Default implementation for other actions
  }

  Future<bool> canPerformAction(String action) async {
    // Default implementation
    return true;
  }
}
