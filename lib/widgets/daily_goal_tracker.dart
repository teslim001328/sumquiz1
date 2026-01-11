import 'package:flutter/material.dart';

class DailyGoalTracker extends StatelessWidget {
  final int itemsCompleted;
  final int dailyGoal;
  final VoidCallback onSetGoal;

  const DailyGoalTracker({
    super.key,
    required this.itemsCompleted,
    required this.dailyGoal,
    required this.onSetGoal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double progress =
        (dailyGoal > 0 ? (itemsCompleted / dailyGoal).clamp(0.0, 1.0) : 0.0);
    final bool isGoalMet = itemsCompleted >= dailyGoal && dailyGoal > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor:
                      theme.colorScheme.primary.withAlpha((255 * 0.1).round()),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isGoalMet ? Colors.greenAccent : theme.colorScheme.primary,
                  ),
                ),
                Center(
                  child: isGoalMet
                      ? const Icon(Icons.check_rounded,
                          size: 40, color: Colors.greenAccent)
                      : Text(itemsCompleted.toString(),
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Goal: $dailyGoal items",
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  isGoalMet
                      ? 'Great job! You met your goal.'
                      : 'Keep going, you are doing great!',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.edit_rounded,
                color: theme.iconTheme.color?.withAlpha((255 * 0.7).round())),
            onPressed: onSetGoal,
            tooltip: 'Set New Goal',
          ),
        ],
      ),
    );
  }
}
