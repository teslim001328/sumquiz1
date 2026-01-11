import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/widgets/achievement_badge.dart';

class AchievementsTracker extends StatelessWidget {
  final int streakDays;
  final int totalItemsCompleted;
  final int quizzesTaken;
  final int flashcardsReviewed;

  const AchievementsTracker({
    super.key,
    required this.streakDays,
    required this.totalItemsCompleted,
    required this.quizzesTaken,
    required this.flashcardsReviewed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context);

    final achievements = [
      {
        'title': 'First Steps',
        'description': 'Complete your first item',
        'icon': Icons.rocket_launch_rounded,
        'earned': totalItemsCompleted >= 1
      },
      {
        'title': 'Consistency King',
        'description': 'Maintain a 7-day streak',
        'icon': Icons.local_fire_department_rounded,
        'earned': streakDays >= 7
      },
      {
        'title': 'Knowledge Seeker',
        'description': 'Complete 50 items',
        'icon': Icons.school_rounded,
        'earned': totalItemsCompleted >= 50
      },
      {
        'title': 'Quiz Master',
        'description': 'Take 10 quizzes',
        'icon': Icons.quiz_rounded,
        'earned': quizzesTaken >= 10
      },
      {
        'title': 'Flashcard Fanatic',
        'description': 'Review 100 flashcards',
        'icon': Icons.flip_to_front_rounded,
        'earned': flashcardsReviewed >= 100
      },
      {
        'title': 'Marathon Learner',
        'description': 'Complete 200 items',
        'icon': Icons.emoji_events_rounded,
        'earned': totalItemsCompleted >= 200
      },
    ];

    final earnedCount = achievements.where((a) => a['earned'] == true).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_rounded,
                  color: theme.colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text('Achievements', style: theme.textTheme.titleLarge),
              const Spacer(),
              Text('$earnedCount/${achievements.length} Unlocked',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (user != null && !user.isPro)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text('Unlock more rewards with a Pro subscription.',
                  style: theme.textTheme.bodySmall),
            ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: achievements.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              return AchievementBadge(
                title: achievement['title'] as String,
                description: achievement['description'] as String,
                icon: achievement['icon'] as IconData,
                isEarned: achievement['earned'] as bool,
                onTap: () {
                  // Potentially show a detail dialog
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
