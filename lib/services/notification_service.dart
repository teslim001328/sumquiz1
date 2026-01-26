import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

final didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotification>();

class ReceivedNotification {
  final int id;
  final String? title;
  final String? body;
  final String? payload;

  ReceivedNotification({
    required this.id,
    this.title,
    this.body,
    this.payload,
  });
}

class NotificationService {
  late final FlutterLocalNotificationsPlugin _localNotifications;
  late final FirebaseMessaging _firebaseMessaging;
  Map<String, dynamic> _notificationTemplates = {};
  static const String notificationEnabledKey = 'notifications_enabled';

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  Future<void> initialize() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    _firebaseMessaging = FirebaseMessaging.instance;
    tz.initializeTimeZones();
    await _loadNotificationTemplates();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationResponse(response);
      },
    );

    // Handle initial notification if app was closed
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final response = notificationAppLaunchDetails!.notificationResponse;
      if (response != null) {
        _handleNotificationResponse(response);
      }
    }

    await _setupPushNotifications();
    await requestPermissions();
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      didReceiveLocalNotificationSubject.add(
        ReceivedNotification(
          id: response.id ?? 0,
          title: response.notificationResponseType ==
                  NotificationResponseType.selectedNotification
              ? response.payload
              : null,
          body: response.notificationResponseType ==
                  NotificationResponseType.selectedNotification
              ? response.payload
              : null,
          payload: response.payload,
        ),
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
    debugPrint('🚫 Cancelled notification: $id');
  }

  Future<void> _loadNotificationTemplates() async {
    final String response =
        await rootBundle.loadString('assets/notification_templates.json');
    _notificationTemplates = await json.decode(response);
  }

  String _getPersonalizedMessage(String category, Map<String, String> data) {
    final List<dynamic> messages = _notificationTemplates[category] ?? [];
    if (messages.isEmpty) {
      return 'Welcome to SumQuiz!'; // Fallback message
    }
    final String message = messages[Random().nextInt(messages.length)];
    String personalizedMessage = message;
    data.forEach((key, value) {
      personalizedMessage = personalizedMessage.replaceAll('{$key}', value);
    });
    return personalizedMessage;
  }

  Future<void> _setupPushNotifications() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotificationFromMessage(message);
    });

    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
          'Opened from terminated state with message: ${initialMessage.data}');
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Opened from background state with message: ${message.data}');
    });
  }

  Future<void> requestPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(notificationEnabledKey) ?? true) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    }
  }

  void _showNotificationFromMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'general_channel',
            'General Notifications',
            channelDescription: 'General app notifications',
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: json.encode(message.data),
      );
    }
  }

  Future<void> showTestNotification() async {
    await scheduleNotification(
      99,
      'Test Notification',
      'system_and_updates',
      {},
      payloadRoute: '/home',
      days: 0, // Schedule for a few seconds from now for testing
    );
  }

  Future<void> scheduleNotification(
    int id,
    String title,
    String category,
    Map<String, String> data, {
    required String payloadRoute,
    int days = 1,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(notificationEnabledKey) ?? true)) return;

    final String message = _getPersonalizedMessage(category, data);
    final tz.TZDateTime scheduledDate = _getScheduledDateTime(days: days);

    await _localNotifications.zonedSchedule(
      id,
      title,
      message,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          '${category}_channel',
          '$category Notifications',
          channelDescription: 'Notifications for $category',
          importance: Importance.max,
          priority: Priority.high,
          color: Colors.black,
          ledColor: Colors.black,
          ledOnMs: 1000,
          ledOffMs: 500,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: json.encode({'route': payloadRoute}),
    );
  }

  tz.TZDateTime _getScheduledDateTime({int days = 1}) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    if (days == 0) {
      return now.add(const Duration(seconds: 5));
    }

    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 10)
            .add(Duration(days: days));

    // If the scheduled time is in the past, schedule it for the next day.
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Ensure notifications are not sent during quiet hours (10 PM to 7 AM)
    if (scheduledDate.hour >= 22 || scheduledDate.hour < 7) {
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7)
          .add(Duration(days: days + (scheduledDate.isBefore(now) ? 1 : 0)));
    }

    return scheduledDate;
  }

  Future<void> toggleNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationEnabledKey, enabled);
    if (!enabled) {
      await _localNotifications.cancelAll();
    }
  }

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notificationEnabledKey) ?? true;
  }

  Future<void> initializeNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Set default value if not set
    if (!prefs.containsKey(notificationEnabledKey)) {
      await prefs.setBool(notificationEnabledKey, true);
    }
  }

  // Mission Engine Notifications

  /// Schedules a "Priming" notification 30 minutes before the user's preferred study time
  Future<void> schedulePrimingNotification({
    required String userId,
    required String preferredStudyTime, // "HH:mm" format
    required int cardCount,
    required int estimatedMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(notificationEnabledKey) ?? true)) return;

    // Parse time
    final parts = preferredStudyTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).subtract(const Duration(minutes: 30)); // 30m before

    // If in the past, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _localNotifications.zonedSchedule(
      1001, // Unique ID for priming notifications
      '🧠 Today\'s Mission is Ready',
      '$cardCount cards • $estimatedMinutes min',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mission_priming',
          'Mission Priming',
          channelDescription: 'Mission preview notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: json.encode({'route': '/review'}),
    );
  }

  /// Schedules a "Recall" notification 20 hours after mission completion
  Future<void> scheduleRecallNotification({
    required int momentumGain,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(notificationEnabledKey) ?? true)) return;

    final tz.TZDateTime scheduledDate =
        tz.TZDateTime.now(tz.local).add(const Duration(hours: 20));

    await _localNotifications.zonedSchedule(
      1002, // Unique ID for recall notifications
      '🚀 Yesterday: +$momentumGain Momentum',
      'Keep the habit alive today!',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mission_recall',
          'Mission Recall',
          channelDescription: 'Encouragement after completion',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: json.encode({'route': '/review'}),
    );
  }

  /// Schedules a "Streak Saver" notification at 8 PM if mission is incomplete
  Future<void> scheduleStreakSaverNotification({
    required int currentStreak,
    required int remainingCards,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(notificationEnabledKey) ?? true)) return;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      20, // 8 PM
      0,
    );

    // If already past 8 PM, skip (don't spam tomorrow)
    if (scheduledDate.isBefore(now)) {
      return;
    }

    await _localNotifications.zonedSchedule(
      1003, // Unique ID for streak saver
      '🔥 Save Your $currentStreak-Day Streak!',
      '$remainingCards cards left • 3 mins to complete',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_saver',
          'Streak Saver',
          channelDescription: 'Urgent reminders to maintain streak',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: json.encode({'route': '/review'}),
    );
  }
}
