import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UpgradeDialog extends StatelessWidget {
  final String featureName;

  const UpgradeDialog({super.key, required this.featureName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      title: Row(
        children: [
          Icon(Icons.workspace_premium_outlined,
              color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upgrade for Unlimited ${featureName.replaceFirst(featureName[0], featureName[0].toUpperCase())}',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Text(
        'You have reached your daily limit. Upgrade to Pro for unlimited access to all features.',
        style: theme.textTheme.bodyLarge,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/settings/subscription');
          },
          child: const Text('Upgrade Now'),
        ),
      ],
    );
  }
}
