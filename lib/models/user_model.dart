import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/time_sync_service.dart';

enum UserRole {
  student,
  creator,
}

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final DateTime? subscriptionExpiry;

  // Progress Tracking Fields
  final double currentMomentum;
  final int dailyGoal;
  final int itemsCompletedToday;
  final int dailyDecksGenerated;
  final int totalDecksGenerated;
  final DateTime? lastDeckGenerationDate;
  final DateTime? updatedAt;
  final double momentumDecayRate; // Default 0.05 (5% daily)
  final int missionCompletionStreak; // Consecutive missions done
  final int difficultyPreference; // Inferred (1-5) based on history
  final String preferredStudyTime; // "HH:mm" format, default "09:00"

  // Freemium Usage Tracking
  final int weeklyUploads;
  final int folderCount;
  final int srsCardCount;
  final DateTime? lastWeeklyReset;
  final UserRole role;

  // Creator Profile
  final Map<String, dynamic> creatorProfile;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = UserRole.student,
    this.subscriptionExpiry,
    this.currentMomentum = 0.0,
    this.momentumDecayRate = 0.05,
    this.missionCompletionStreak = 0,
    this.difficultyPreference = 3,
    this.preferredStudyTime = "09:00",
    this.dailyGoal = 5,
    this.itemsCompletedToday = 0,
    this.weeklyUploads = 0,
    this.folderCount = 0,
    this.srsCardCount = 0,
    this.lastWeeklyReset,
    this.dailyDecksGenerated = 0,
    this.totalDecksGenerated = 0,
    this.lastDeckGenerationDate,
    this.updatedAt,
    this.creatorProfile = const {},
  });

  bool get isPro {
    // CRITICAL FIX: null subscriptionExpiry indicates lifetime Pro access
    // This matches IAPService.isProStream logic
    if (subscriptionExpiry == null) return true;

    // For time-limited subscriptions, check if not expired
    // SECURITY: Use server-synced time to prevent device time manipulation
    return subscriptionExpiry!.isAfter(TimeSyncService.now);
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      subscriptionExpiry: (data['subscriptionExpiry'] as Timestamp?)?.toDate(),
      currentMomentum: (data['currentMomentum'] as num?)?.toDouble() ?? 0.0,
      momentumDecayRate:
          (data['momentumDecayRate'] as num?)?.toDouble() ?? 0.05,
      missionCompletionStreak: data['missionCompletionStreak'] ?? 0,
      difficultyPreference: data['difficultyPreference'] ?? 3,
      preferredStudyTime: data['preferredStudyTime'] ?? "09:00",
      dailyGoal: data['dailyGoal'] ?? 5,
      itemsCompletedToday: data['itemsCompletedToday'] ?? 0,
      weeklyUploads: data['weeklyUploads'] ?? 0,
      folderCount: data['folderCount'] ?? 0,
      srsCardCount: data['srsCardCount'] ?? 0,
      lastWeeklyReset: (data['lastWeeklyReset'] as Timestamp?)?.toDate(),
      dailyDecksGenerated: data['dailyDecksGenerated'] ?? 0,
      totalDecksGenerated: data['totalDecksGenerated'] ?? 0,
      lastDeckGenerationDate:
          (data['lastDeckGenerationDate'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      role: UserRole.values.firstWhere(
        (e) => e.name == (data['role'] ?? 'student'),
        orElse: () => UserRole.student,
      ),
      creatorProfile: data['creatorProfile'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name,
      if (subscriptionExpiry != null)
        'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry!),
      'currentMomentum': currentMomentum,
      'momentumDecayRate': momentumDecayRate,
      'missionCompletionStreak': missionCompletionStreak,
      'difficultyPreference': difficultyPreference,
      'preferredStudyTime': preferredStudyTime,
      'dailyGoal': dailyGoal,
      'itemsCompletedToday': itemsCompletedToday,
      'weeklyUploads': weeklyUploads,
      'folderCount': folderCount,
      'srsCardCount': srsCardCount,
      'dailyDecksGenerated': dailyDecksGenerated,
      'totalDecksGenerated': totalDecksGenerated,
      if (lastDeckGenerationDate != null)
        'lastDeckGenerationDate': Timestamp.fromDate(lastDeckGenerationDate!),
      if (lastWeeklyReset != null)
        'lastWeeklyReset': Timestamp.fromDate(lastWeeklyReset!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'creatorProfile': creatorProfile,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? subscriptionExpiry,
    double? currentMomentum,
    double? momentumDecayRate,
    int? missionCompletionStreak,
    int? difficultyPreference,
    String? preferredStudyTime,
    int? dailyGoal,
    int? itemsCompletedToday,
    int? weeklyUploads,
    int? folderCount,
    int? srsCardCount,
    int? dailyDecksGenerated,
    int? totalDecksGenerated,
    DateTime? lastDeckGenerationDate,
    DateTime? lastWeeklyReset,
    DateTime? updatedAt,
    UserRole? role,
    Map<String, dynamic>? creatorProfile,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      currentMomentum: currentMomentum ?? this.currentMomentum,
      momentumDecayRate: momentumDecayRate ?? this.momentumDecayRate,
      missionCompletionStreak:
          missionCompletionStreak ?? this.missionCompletionStreak,
      difficultyPreference: difficultyPreference ?? this.difficultyPreference,
      preferredStudyTime: preferredStudyTime ?? this.preferredStudyTime,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      itemsCompletedToday: itemsCompletedToday ?? this.itemsCompletedToday,
      weeklyUploads: weeklyUploads ?? this.weeklyUploads,
      folderCount: folderCount ?? this.folderCount,
      srsCardCount: srsCardCount ?? this.srsCardCount,
      dailyDecksGenerated: dailyDecksGenerated ?? this.dailyDecksGenerated,
      totalDecksGenerated: totalDecksGenerated ?? this.totalDecksGenerated,
      lastDeckGenerationDate:
          lastDeckGenerationDate ?? this.lastDeckGenerationDate,
      lastWeeklyReset: lastWeeklyReset ?? this.lastWeeklyReset,
      updatedAt: updatedAt ?? this.updatedAt,
      creatorProfile: creatorProfile ?? this.creatorProfile,
    );
  }
}
