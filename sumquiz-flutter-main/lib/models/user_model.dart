import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/time_sync_service.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final DateTime? subscriptionExpiry;

  // Mission Engine 2.0 Fields
  final double currentMomentum; // Living score (0-500+)
  final double momentumDecayRate; // Default 0.05 (5% daily)
  final int missionCompletionStreak; // Consecutive missions done
  final int difficultyPreference; // Inferred (1-5) based on history
  final String preferredStudyTime; // "HH:mm" format, default "09:00"

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.subscriptionExpiry,
    this.currentMomentum = 0.0,
    this.momentumDecayRate = 0.05,
    this.missionCompletionStreak = 0,
    this.difficultyPreference = 3,
    this.preferredStudyTime = "09:00",
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
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      if (subscriptionExpiry != null)
        'subscriptionExpiry': Timestamp.fromDate(subscriptionExpiry!),
      'currentMomentum': currentMomentum,
      'momentumDecayRate': momentumDecayRate,
      'missionCompletionStreak': missionCompletionStreak,
      'difficultyPreference': difficultyPreference,
      'preferredStudyTime': preferredStudyTime,
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
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      currentMomentum: currentMomentum ?? this.currentMomentum,
      momentumDecayRate: momentumDecayRate ?? this.momentumDecayRate,
      missionCompletionStreak:
          missionCompletionStreak ?? this.missionCompletionStreak,
      difficultyPreference: difficultyPreference ?? this.difficultyPreference,
      preferredStudyTime: preferredStudyTime ?? this.preferredStudyTime,
    );
  }
}
