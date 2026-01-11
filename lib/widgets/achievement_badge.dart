import 'package:flutter/material.dart';

class AchievementBadge extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isEarned;
  final VoidCallback? onTap;

  const AchievementBadge({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.isEarned = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color iconColor =
        isEarned ? theme.colorScheme.secondary : theme.disabledColor;
    final Color textColor =
        isEarned ? theme.textTheme.bodyLarge!.color! : theme.disabledColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isEarned
                  ? theme.colorScheme.secondary.withOpacity(0.5)
                  : Colors.transparent,
              width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isEarned)
              Icon(
                Icons.workspace_premium_rounded,
                color: theme.colorScheme.secondary,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
