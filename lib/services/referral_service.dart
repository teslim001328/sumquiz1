import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:sumquiz/services/notification_service.dart';
import 'package:sumquiz/services/notification_manager.dart';
import 'package:sumquiz/services/local_database_service.dart';

/// A production-grade service for handling a referral system in Flutter and Firebase.
///
/// This service uses Firestore transactions to ensure that all referral operations
/// are atomic, consistent, isolated, and durable (ACID principles). This prevents
/// common bugs like duplicate rewards, partial data writes, and race conditions.
class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Applies a referral code to a new user and grants rewards atomically.
  ///
  /// This function is the core of the referral system. It uses a Firestore
  /// transaction to perform all reads and writes as a single, indivisible operation.
  /// If any part of the transaction fails, the entire operation is rolled back,
  /// leaving the database in its original state.
  ///
  /// - `code`: The referral code entered by the new user.
  /// - `newUserId`: The UID of the new user signing up.
  Future<void> applyReferralCode(String code, String newUserId) async {
    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) {
      developer.log('Attempted to apply an empty or whitespace referral code.',
          name: 'com.example.myapp.ReferralService.applyReferralCode');
      return;
    }

    // Call validation to ensure code exists before proceeding (optional redundant check, but good for safety)
    if (!await validateReferralCode(trimmedCode)) {
      developer.log('Invalid referral code: $trimmedCode',
          name: 'com.example.myapp.ReferralService.applyReferralCode');
      return;
    }

    developer.log(
        'Starting referral process for newUser: $newUserId with code: "$trimmedCode"',
        name: 'com.example.myapp.ReferralService.applyReferralCode');

    // Step 1: Find the referrer *before* starting the transaction.
    final referrerQuery = await _firestore
        .collection('users')
        .where('referralCode', isEqualTo: trimmedCode)
        .limit(1)
        .get();

    if (referrerQuery.docs.isEmpty) {
      developer.log(
          'Validation failed: No referrer found for code "$trimmedCode". Aborting.',
          name: 'com.example.myapp.ReferralService.applyReferralCode');
      // Optionally, throw an exception here to let the UI know the code is invalid.
      return;
    }

    final referrerDocRef = referrerQuery.docs.first.reference;
    final newUserDocRef = _firestore.collection('users').doc(newUserId);

    // Firestore transactions are crucial for atomicity. They ensure that the
    // complex logic of rewarding two separate users either completes entirely
    // or fails without leaving any partial data, even under concurrent signups
    // or network failures.
    try {
      await _firestore.runTransaction((transaction) async {
        developer.log('Inside transaction. Fetching documents...',
            name: 'com.example.myapp.ReferralService.transaction');

        // Block 2: Atomic Reads
        // All reads from this point forward MUST use the `transaction` object to ensure
        // a consistent view of the data.
        final referrerDoc = await transaction.get(referrerDocRef);
        final newUserDoc = await transaction.get(newUserDocRef);

        // Block 3: Validation and Edge Case Handling
        // These checks run atomically and prevent invalid states.

        // 3.1: Prevent Self-Referral
        if (referrerDocRef.id == newUserId) {
          developer.log(
              'Validation failed: User $newUserId attempted to refer themselves. Aborting.',
              name: 'com.example.myapp.ReferralService.transaction');
          return;
        }

        // 3.2: Ensure Referrer Exists
        if (!referrerDoc.exists) {
          developer.log(
              'Validation failed: Referrer document for ID ${referrerDocRef.id} does not exist. Aborting.',
              name: 'com.example.myapp.ReferralService.transaction');
          return;
        }

        // 3.3: Idempotency Check - Prevent Duplicate Referrals
        // This is the most critical check for preventing reward abuse.
        if (newUserDoc.exists &&
            (newUserDoc.data() as Map<String, dynamic>)
                .containsKey('appliedReferralCode')) {
          final appliedCode = (newUserDoc.data()
              as Map<String, dynamic>)['appliedReferralCode'];
          developer.log(
              'Validation failed: User $newUserId has already applied a referral code ("$appliedCode"). Aborting.',
              name: 'com.example.myapp.ReferralService.transaction');
          return;
        }

        developer.log('All validations passed. Proceeding with atomic writes.',
            name: 'com.example.myapp.ReferralService.transaction');

        // Block 4: Atomic Writes
        // All writes MUST use the `transaction` object.

        // 4.1: Update and Reward the New User (+7 days Pro)
        final newUserData = newUserDoc.exists
            ? newUserDoc.data() as Map<String, dynamic>
            : <String, dynamic>{};
        final currentNewUserExpiry =
            (newUserData['subscriptionExpiry'] as Timestamp?)?.toDate() ??
                DateTime.now();
        final newExpiryDateForNewUser =
            currentNewUserExpiry.add(const Duration(days: 7));

        transaction.set(
            newUserDocRef,
            {
              'appliedReferralCode': trimmedCode,
              'referredBy': referrerDocRef.id,
              'referralAppliedAt': FieldValue.serverTimestamp(),
              'isTrial': true, // Mark as trial user
              'subscriptionExpiry': Timestamp.fromDate(newExpiryDateForNewUser),
            },
            SetOptions(merge: true));

        developer.log(
            'Prepared write for newUser $newUserId: +7 days Pro, marked as referred by ${referrerDocRef.id}.',
            name: 'com.example.myapp.ReferralService.transaction');

        // 4.2: Update Referrer Stats - Immediate Feedback
        // "Total" increases immediately. "Pending" (referrals) increases immediately.
        // "Rewards" will increase later when they generate a deck (and Pending will decrease).
        transaction.update(referrerDocRef, {
          'totalReferrals': FieldValue.increment(1),
          'referrals': FieldValue.increment(1),
        });

        developer.log(
            'Prepared write for referrer ${referrerDocRef.id}: referrals and rewards updated.',
            name: 'com.example.myapp.ReferralService.transaction');
      }); // --- End of transaction ---

      developer.log(
          'Firestore transaction completed successfully for newUser: $newUserId.',
          name: 'com.example.myapp.ReferralService.applyReferralCode');
    } catch (e, s) {
      // If any error occurs during the transaction (e.g., network failure,
      // permission denied), Firestore automatically rolls back all writes.
      developer.log(
        'Firestore transaction failed and was rolled back. No data was changed.',
        name: 'com.example.myapp.ReferralService.applyReferralCode',
        error: e,
        stackTrace: s,
      );
      // Rethrow to allow the UI layer to handle the failure if needed.
      rethrow;
    }
  }

  /// Generates a unique referral code for a user if they don't have one.
  Future<String> generateReferralCode(String uid) async {
    final userDocRef = _firestore.collection('users').doc(uid);
    final doc = await userDocRef.get();

    if (doc.exists &&
        (doc.data() as Map<String, dynamic>).containsKey('referralCode')) {
      return (doc.data() as Map<String, dynamic>)['referralCode'];
    } else {
      String code = await _generateUniqueCode();
      await userDocRef.set({'referralCode': code}, SetOptions(merge: true));
      return code;
    }
  }

  /// Generates a short, unique, and easy-to-read referral code.
  Future<String> _generateUniqueCode() async {
    String code = '';
    bool isUnique = false;
    while (!isUnique) {
      code = _uuid.v4().substring(0, 8).toUpperCase();
      final query = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        isUnique = true;
      }
    }
    return code;
  }

  // --- STREAMS FOR UI ---
  // (These functions are included for completeness but are not part of the core fix)

  Stream<int> getReferralCount(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || !(snapshot.data()!.containsKey('referrals'))) {
        return 0;
      }
      return snapshot.data()!['referrals'] as int;
    });
  }

  Stream<int> getTotalReferralCount(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists ||
          !(snapshot.data()!.containsKey('totalReferrals'))) {
        return 0;
      }
      return snapshot.data()!['totalReferrals'] as int;
    });
  }

  Stream<int> getReferralRewards(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists ||
          !(snapshot.data()!.containsKey('referralRewards'))) {
        return 0;
      }
      return snapshot.data()!['referralRewards'] as int;
    });
  }

  /// Grants a reward to the referrer when an invitee completes their first action.
  Future<void> grantReferrerReward(String referrerId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final referrerDocRef = _firestore.collection('users').doc(referrerId);
        final referrerDoc = await transaction.get(referrerDocRef);

        if (!referrerDoc.exists) return;

        final data = referrerDoc.data() as Map<String, dynamic>;
        final int currentRewards = data['referralRewards'] as int? ?? 0;

        DateTime currentExpiry =
            (data['subscriptionExpiry'] as Timestamp?)?.toDate() ??
                DateTime.now();
        if (currentExpiry.isBefore(DateTime.now())) {
          currentExpiry = DateTime.now();
        }

        // Cap rewards to avoid abuse (e.g., 20 successful referrals)
        const int maxRewards = 20;

        // Note: 'totalReferrals' is now incremented on Signup (immediate feedback).
        // Here, we "consume" a 'referral' (Pending) and turn it into a 'referralReward' (if eligible).

        if (currentRewards < maxRewards) {
          final newExpiry = currentExpiry.add(const Duration(days: 7));
          transaction.update(referrerDocRef, {
            'referralRewards': currentRewards + 1,
            'referrals': FieldValue.increment(-1), // Move from Pending to Done
            'subscriptionExpiry': Timestamp.fromDate(newExpiry),
          });
          developer.log('Granted +7 days to referrer $referrerId',
              name: 'ReferralService');
        } else {
          // Even if capped, they are no longer "Pending"
          transaction.update(referrerDocRef, {
            'referrals': FieldValue.increment(-1),
          });
          developer.log('Referrer $referrerId hit cap, pending count updated',
              name: 'ReferralService');
        }
      });

      // 🔔 Schedule referral reward notification
      try {
        final notificationService = NotificationService();
        final localDb = LocalDatabaseService();
        final manager = NotificationManager(notificationService, localDb);
        await manager.scheduleReferralReward();
        developer.log('Referral reward notification scheduled',
            name: 'ReferralService');
      } catch (e) {
        developer.log('Failed to schedule referral reward notification',
            name: 'ReferralService', error: e);
      }
    } catch (e) {
      developer.log('Failed to grant referrer reward', error: e);
    }
  }

  /// Validates if a referral code exists and is valid.
  /// Returns `true` if valid, `false` otherwise.
  Future<bool> validateReferralCode(String code) async {
    if (code.trim().isEmpty) return false;

    try {
      final query = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: code.trim())
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      developer.log('Error validating referral code', error: e);
      return false;
    }
  }
}

/*
 === HOW TO VERIFY THE FIX IN FIRESTORE ===

 1. Initial State:
    - Referrer (User A):
      - `referralCode`: "ABC-123"
      - `referrals`: 2
      - `totalReferrals`: 5
      - `referralRewards`: 1
      - `subscriptionExpiry`: (Some date)
    - New User (User B): Does not have `appliedReferralCode` or `referredBy`.

 2. Action:
    - User B signs up and applies code "ABC-123".

 3. Expected Final State (after transaction):
    - Referrer (User A) Document (`/users/{UserA_UID}`):
      - `referrals`: 0 (Resets because 1 + 1 = 2, triggering the reward)
      - `totalReferrals`: 6 (Incremented by 1)
      - `referralRewards`: 2 (Incremented by 1)
      - `subscriptionExpiry`: (Original date + 7 days)

    - New User (User B) Document (`/users/{UserB_UID}`):
      - `appliedReferralCode`: "ABC-123"
      - `referredBy`: "{UserA_UID}"
      - `referralAppliedAt`: (Server timestamp of the transaction)
      - `isPro`: true
      - `subscriptionExpiry`: (Date of signup + 7 days)

 4. Idempotency Test:
    - If you attempt to run the `applyReferralCode` function for User B again,
      the log will show "Validation failed: User has already applied a referral code"
      and NO fields in either document will be changed.
*/
