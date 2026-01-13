import 'package:sumquiz/services/notification_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/local_database_service.dart';

/// Comprehensive notification manager that schedules all app notifications
/// Uses templates from assets/notification_templates.json
class NotificationManager {
  final NotificationService _notificationService;
  final LocalDatabaseService _localDb;

  NotificationManager(this._notificationService, this._localDb);

  // ============================================================================
  // LEARNING ENGAGEMENT NOTIFICATIONS
  // ============================================================================

  /// Schedule daily learning reminder
  Future<void> scheduleDailyLearningReminder(UserModel user) async {
    await _notificationService.scheduleNotification(
      100, // Unique ID
      'Time to Learn! 📚',
      'learning_engagement',
      {'name': user.displayName.split(' ').first},
      payloadRoute: '/library',
      days: 1, // Tomorrow at 10 AM
    );
  }

  /// Schedule quiz reminder after 3 days of inactivity
  Future<void> scheduleInactivityReminder(UserModel user) async {
    await _notificationService.scheduleNotification(
      101,
      'We Miss You! 👋',
      'learning_engagement',
      {'name': user.displayName.split(' ').first},
      payloadRoute: '/create',
      days: 3,
    );
  }

  /// Schedule flashcard review reminder
  Future<void> scheduleFlashcardReview(UserModel user) async {
    await _notificationService.scheduleNotification(
      102,
      'Review Time! 🎯',
      'learning_engagement',
      {'name': user.displayName.split(' ').first},
      payloadRoute: '/library',
      days: 1,
    );
  }

  // ============================================================================
  // CONTENT-BASED NUDGES
  // ============================================================================

  /// Schedule notification after completing a quiz
  Future<void> schedulePostQuizNudge(String topic) async {
    await _notificationService.scheduleNotification(
      200,
      'Great Job! 🎉',
      'content_based_nudges',
      {'topic': topic},
      payloadRoute: '/library',
      days: 1,
    );
  }

  /// Schedule personalized topic recommendation
  Future<void> scheduleTopicRecommendation(
      String topic, String relatedTopic) async {
    await _notificationService.scheduleNotification(
      201,
      'New Content Ready! 📖',
      'content_based_nudges',
      {'topic': topic, 'related_topic': relatedTopic},
      payloadRoute: '/library',
      days: 2,
    );
  }

  /// Schedule challenge notification
  Future<void> scheduleChallenge(String topic) async {
    await _notificationService.scheduleNotification(
      202,
      'Challenge Time! 💪',
      'content_based_nudges',
      {'topic': topic},
      payloadRoute: '/library',
      days: 1,
    );
  }

  // ============================================================================
  // PRO CONVERSION TRIGGERS
  // ============================================================================

  /// Schedule Pro upgrade reminder after hitting free limit
  Future<void> scheduleProUpgradeReminder() async {
    await _notificationService.scheduleNotification(
      300,
      'Unlock Your Potential! ⭐',
      'pro_conversion_triggers',
      {},
      payloadRoute: '/settings/subscription',
      days: 1,
    );
  }

  /// Schedule Pro feature showcase
  Future<void> scheduleProFeatureShowcase() async {
    await _notificationService.scheduleNotification(
      301,
      'Discover Pro Features! 🚀',
      'pro_conversion_triggers',
      {},
      payloadRoute: '/settings/subscription',
      days: 3,
    );
  }

  /// Schedule Pro trial reminder
  Future<void> scheduleProTrialReminder() async {
    await _notificationService.scheduleNotification(
      302,
      'Limited Time Offer! 🎁',
      'pro_conversion_triggers',
      {},
      payloadRoute: '/settings/subscription',
      days: 7,
    );
  }

  // ============================================================================
  // REFERRAL PROGRAM
  // ============================================================================

  /// Schedule referral invitation reminder
  Future<void> scheduleReferralReminder() async {
    await _notificationService.scheduleNotification(
      400,
      'Share & Earn! 🎁',
      'referral_program',
      {},
      payloadRoute: '/settings/referral',
      days: 7,
    );
  }

  /// Schedule referral reward notification
  Future<void> scheduleReferralReward() async {
    await _notificationService.scheduleNotification(
      401,
      'Referral Bonus! 🎉',
      'referral_program',
      {},
      payloadRoute: '/settings/referral',
      days: 1,
    );
  }

  // ============================================================================
  // SYSTEM & UPDATES
  // ============================================================================

  /// Schedule new feature announcement
  Future<void> scheduleNewFeatureAnnouncement() async {
    await _notificationService.scheduleNotification(
      500,
      'New Feature! 🎉',
      'system_and_updates',
      {},
      payloadRoute: '/create',
      days: 0, // Immediate
    );
  }

  /// Schedule maintenance notification
  Future<void> scheduleMaintenanceNotification() async {
    await _notificationService.scheduleNotification(
      501,
      'Scheduled Maintenance ⚙️',
      'system_and_updates',
      {},
      payloadRoute: '/',
      days: 1,
    );
  }

  /// Schedule welcome notification for new users
  Future<void> scheduleWelcomeNotification(UserModel user) async {
    await _notificationService.scheduleNotification(
      502,
      'Welcome to SumQuiz! 👋',
      'system_and_updates',
      {'name': user.displayName.split(' ').first},
      payloadRoute: '/create',
      days: 0, // Immediate
    );
  }

  // ============================================================================
  // MISSION-BASED NOTIFICATIONS
  // ============================================================================

  /// Schedule daily mission priming notification
  Future<void> scheduleDailyMissionPriming({
    required String userId,
    required String preferredStudyTime,
    required int cardCount,
    required int estimatedMinutes,
  }) async {
    await _notificationService.schedulePrimingNotification(
      userId: userId,
      preferredStudyTime: preferredStudyTime,
      cardCount: cardCount,
      estimatedMinutes: estimatedMinutes,
    );
  }

  /// Schedule mission recall notification
  Future<void> scheduleMissionRecall({required int momentumGain}) async {
    await _notificationService.scheduleRecallNotification(
      momentumGain: momentumGain,
    );
  }

  /// Schedule streak saver notification
  Future<void> scheduleStreakSaver({
    required int currentStreak,
    required int remainingCards,
  }) async {
    await _notificationService.scheduleStreakSaverNotification(
      currentStreak: currentStreak,
      remainingCards: remainingCards,
    );
  }

  // ============================================================================
  // SMART SCHEDULING
  // ============================================================================

  /// Schedule all appropriate notifications for a user
  Future<void> scheduleAllNotifications(UserModel user) async {
    // Daily learning reminder
    await scheduleDailyLearningReminder(user);

    // Schedule referral reminder weekly
    await scheduleReferralReminder();
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationService.toggleNotifications(false);
  }

  /// Re-enable all notifications
  Future<void> enableAllNotifications() async {
    await _notificationService.toggleNotifications(true);
  }

}
