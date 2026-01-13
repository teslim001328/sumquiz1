import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';

/// A widget that conditionally displays content based on the user's Pro status
/// and usage limits for FREE tier users.
class ProGate extends StatelessWidget {
  final Widget Function() proContent;
  final Widget? freeContent;
  final String featureName;
  final bool
      requiresPro; // Whether this feature requires Pro regardless of limits
  final int? freeTierLimit; // Limit for FREE tier users (null = unlimited)
  final int? currentUsage; // Current usage count for FREE tier users

  const ProGate({
    super.key,
    required this.proContent,
    this.freeContent,
    required this.featureName,
    this.requiresPro = false,
    this.freeTierLimit,
    this.currentUsage,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel?>();

    // If feature requires Pro regardless of limits
    if (requiresPro) {
      if (user?.isPro ?? false) {
        return proContent();
      } else {
        return _buildUpgradePrompt(context);
      }
    }

    // If user is Pro, show the full feature
    if (user?.isPro ?? false) {
      return proContent();
    }

    // For FREE users, check usage limits
    if (freeTierLimit != null && currentUsage != null) {
      if (currentUsage! < freeTierLimit!) {
        return proContent();
      } else {
        // Show limited version or upgrade prompt
        if (freeContent != null) {
          return freeContent!;
        } else {
          return _buildUpgradePrompt(context);
        }
      }
    }

    // Default behavior for FREE users
    if (freeContent != null) {
      return freeContent!;
    } else {
      return _buildUpgradePrompt(context);
    }
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock $featureName',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to SumQuiz Pro to access this feature',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to subscription screen
              Navigator.of(context).pushNamed('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }
}
