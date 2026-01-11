import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';

class ProStatusWidget extends StatelessWidget {
  const ProStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel?>();
    final theme = Theme.of(context);

    if (user == null) {
      return const SizedBox.shrink();
    }

    final isPro = user.isPro;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isPro
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.tertiaryContainer,
      child: InkWell(
        onTap: isPro ? null : () => context.go('/subscription'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(
                isPro ? Icons.star : Icons.lock_outline,
                color: isPro
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 12),
              Text(
                isPro ? 'Pro Member' : 'Upgrade to Pro',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPro
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onTertiaryContainer,
                ),
              ),
              const Spacer(),
              if (!isPro)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
