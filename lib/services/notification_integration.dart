import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sumquiz/services/notification_service.dart';
import 'package:sumquiz/services/notification_manager.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/auth_service.dart';

/// Centralized notification integration helper
/// Call these methods at appropriate points in your app
class NotificationIntegration {
  /// 1. AFTER USER REGISTRATION
  /// Call in: lib/services/auth_service.dart after signUpWithEmailAndPassword
  static Future<void> onUserRegistered(
    BuildContext context,
    String userId,
  ) async {
    try {
      // Get user model from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return;
      final user = UserModel.fromFirestore(userDoc);

      final notificationManager = NotificationManager(
        context.read<NotificationService>(),
        context.read<LocalDatabaseService>(),
      );

      // Welcome notification (immediate)
      await notificationManager.scheduleWelcomeNotification(user);

      // Schedule all recurring notifications
      await notificationManager.scheduleAllNotifications(user);

      debugPrint('✅ Notifications scheduled for new user: ${user.displayName}');
    } catch (e) {
      debugPrint('❌ Failed to schedule notifications for new user: $e');
    }
  }

  /// 2. AFTER CONTENT GENERATION
  /// Call in: lib/services/enhanced_ai_service.dart after generateAndStoreOutputs
  static Future<void> onContentGenerated(
    BuildContext context,
    String userId,
    String title,
  ) async {
    try {
      // Get user model from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return;
      final user = UserModel.fromFirestore(userDoc);

      final notificationManager = NotificationManager(
        context.read<NotificationService>(),
        context.read<LocalDatabaseService>(),
      );

      // Extract topic from title (first word or full title if short)
      final topic = title.split(' ').first;

      // Schedule daily learning reminder
      await notificationManager.scheduleDailyLearningReminder(user);

      // Schedule topic recommendation
      await notificationManager.scheduleTopicRecommendation(topic, topic);

      debugPrint('✅ Notifications scheduled after content generation');
    } catch (e) {
      debugPrint(
          '❌ Failed to schedule notifications after content generation: $e');
    }
  }

  /// 3. AFTER QUIZ COMPLETION
  /// Call in: lib/views/screens/quiz_screen.dart after quiz finishes
  static Future<void> onQuizCompleted(
    BuildContext context,
    String topic,
    double score,
  ) async {
    try {
      final notificationManager = NotificationManager(
        context.read<NotificationService>(),
        context.read<LocalDatabaseService>(),
      );

      // Schedule post-quiz nudge
      await notificationManager.schedulePostQuizNudge(topic);

      // If high score, schedule challenge
      if (score >= 0.8) {
        await notificationManager.scheduleChallenge(topic);
      }

      debugPrint('✅ Notifications scheduled after quiz completion');
    } catch (e) {
      debugPrint('❌ Failed to schedule notifications after quiz: $e');
    }
  }

  /// 4. WHEN USAGE LIMIT HIT
  /// Call in: lib/services/usage_service.dart when limit reached
  static Future<void> onUsageLimitHit(BuildContext context) async {
    try {
      final notificationManager = NotificationManager(
        context.read<NotificationService>(),
        context.read<LocalDatabaseService>(),
      );

      // Schedule Pro upgrade reminder
      await notificationManager.scheduleProUpgradeReminder();

      debugPrint('✅ Pro upgrade notification scheduled');
    } catch (e) {
      debugPrint('❌ Failed to schedule Pro upgrade notification: $e');
    }
  }

  /// 5. AFTER DAILY MISSION GENERATION
  /// Call in: lib/services/mission_service.dart after generateDailyMission
  static Future<void> onDailyMissionGenerated(
    BuildContext context, {
    required String userId,
    required int cardCount,
  }) async {
    try {
      // Get user model from Firestore for preferred study time
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      String preferredStudyTime = '10:00'; // Default if not set
      if (userDoc.exists) {
        final user = UserModel.fromFirestore(userDoc);
        preferredStudyTime = user.preferredStudyTime;
      }

      final notificationManager = NotificationManager(
        context.read<NotificationService>(),
        context.read<LocalDatabaseService>(),
      );

      final estimatedMinutes = (cardCount * 0.6).ceil(); // ~36 seconds per card

      // Schedule priming notification (30 min before)
      await notificationManager.scheduleDailyMissionPriming(
        userId: userId,
        preferredStudyTime: preferredStudyTime,
        cardCount: cardCount,
        estimatedMinutes: estimatedMinutes,
      );

      debugPrint(
          '✅ Mission priming notification scheduled for $preferredStudyTime');
    } catch (e) {
      debugPrint('❌ Failed to schedule mission priming: $e');
    }
  }

  /// 6. AFTER MISSION COMPLETION
  /// Call in: lib/services/mission_service.dart after completeMission
  static Future<void> onMissionCompleted(
    BuildContext context, {
    required int momentumGain,
  }) async {
    try {
      final notificationService = context.read<NotificationService>();
      final notificationManager = NotificationManager(
        notificationService,
        context.read<LocalDatabaseService>(),
      );

      // 🚫 Cancel streak saver notification for today if it was scheduled
      await notificationService.cancelNotification(1003);

      // Schedule recall notification (20 hours later)
      await notificationManager.scheduleMissionRecall(
        momentumGain: momentumGain,
      );

      debugPrint(
          '✅ Mission recall notification scheduled and streak saver cancelled');
    } catch (e) {
      debugPrint('❌ Failed to schedule mission recall: $e');
    }
  }

  /// 7. WHEN MISSION INCOMPLETE (8 PM CHECK)
  /// Call in: lib/services/mission_service.dart at 8 PM if incomplete
  static Future<void> onMissionIncomplete(
    BuildContext context, {
    required int currentStreak,
    required int remainingCards,
  }) async {
    try {
      final notificationManager = NotificationManager(
        context.read<NotificationService>(),
        context.read<LocalDatabaseService>(),
      );

      // Schedule streak saver notification
      await notificationManager.scheduleStreakSaver(
        currentStreak: currentStreak,
        remainingCards: remainingCards,
      );

      debugPrint('✅ Streak saver notification scheduled');
    } catch (e) {
      debugPrint('❌ Failed to schedule streak saver: $e');
    }
  }

  /// 8. AFTER 3 DAYS INACTIVITY
  /// Call in: background task or app launch check
  static Future<void> onInactivityDetected(
    BuildContext context,
    UserModel user,
  ) async {
    try {
      final notificationManager = NotificationManager(
        context.read<NotificationService>(),
        context.read<LocalDatabaseService>(),
      );

      // Schedule inactivity reminder
      await notificationManager.scheduleInactivityReminder(user);

      debugPrint('✅ Inactivity reminder scheduled');
    } catch (e) {
      debugPrint('❌ Failed to schedule inactivity reminder: $e');
    }
  }

  /// 9. ON APP LAUNCH (CHECK AND SCHEDULE)
  /// Call in: lib/main.dart after app initialization
  static Future<void> onAppLaunch(
    BuildContext context,
    UserModel? user,
  ) async {
    if (user == null) return;

    try {
      final notificationManager = NotificationManager(
        context.read<NotificationService>(),
        context.read<LocalDatabaseService>(),
      );

      // Schedule all appropriate notifications
      await notificationManager.scheduleAllNotifications(user);

      debugPrint('✅ All notifications scheduled on app launch');
    } catch (e) {
      debugPrint('❌ Failed to schedule notifications on app launch: $e');
    }
  }

  /// 10. REFERRAL SUCCESS
  /// Call in: lib/services/referral_service.dart after successful referral
  static Future<void> onReferralSuccess(BuildContext context) async {
    try {
      final notificationManager = NotificationManager(
        context.read<NotificationService>(),
        context.read<LocalDatabaseService>(),
      );

      // Schedule referral reward notification
      await notificationManager.scheduleReferralReward();

      debugPrint('✅ Referral reward notification scheduled');
    } catch (e) {
      debugPrint('❌ Failed to schedule referral reward: $e');
    }
  }

  /// TEST NOTIFICATION (FOR DEBUGGING)
  /// Call from settings or debug screen
  static Future<void> testNotification(BuildContext context) async {
    try {
      final notificationService = context.read<NotificationService>();
      await notificationService.showTestNotification();

      debugPrint('✅ Test notification sent');
    } catch (e) {
      debugPrint('❌ Failed to send test notification: $e');
    }
  }

  /// DISABLE ALL NOTIFICATIONS
  /// Call from settings screen
  static Future<void> disableNotifications(BuildContext context) async {
    try {
      final notificationManager = NotificationManager(
        context.read<NotificationService>(),
        context.read<LocalDatabaseService>(),
      );

      await notificationManager.cancelAllNotifications();

      debugPrint('✅ All notifications disabled');
    } catch (e) {
      debugPrint('❌ Failed to disable notifications: $e');
    }
  }

  /// ENABLE ALL NOTIFICATIONS
  /// Call from settings screen
  static Future<void> enableNotifications(BuildContext context) async {
    try {
      final notificationManager = NotificationManager(
        context.read<NotificationService>(),
        context.read<LocalDatabaseService>(),
      );

      await notificationManager.enableAllNotifications();

      // Reschedule notifications for current user
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      if (user != null) {
        // Get user model from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userModel = UserModel.fromFirestore(userDoc);
          await notificationManager.scheduleAllNotifications(userModel);
        }
      }

      debugPrint('✅ All notifications enabled');
    } catch (e) {
      debugPrint('❌ Failed to enable notifications: $e');
    }
  }
}

/// Extension methods for easy integration
extension NotificationContextExtension on BuildContext {
  /// Quick access to notification integration
  NotificationService get notifications => read<NotificationService>();

  /// Quick access to notification manager
  NotificationManager get notificationManager => NotificationManager(
        read<NotificationService>(),
        read<LocalDatabaseService>(),
      );
}
