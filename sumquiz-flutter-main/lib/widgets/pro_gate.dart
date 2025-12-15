import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/iap_service.dart';

/// Widget that gates content behind Pro subscription
/// Shows paywall if user doesn't have Pro access
class ProGate extends StatelessWidget {
  final Widget child;
  final String featureName;
  final bool showFullScreen;

  const ProGate({
    super.key,
    required this.child,
    required this.featureName,
    this.showFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return _buildLoginPrompt(context);
    }

    return StreamBuilder<bool>(
      stream:
          Provider.of<IAPService?>(context, listen: false)?.isProStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final hasPro = snapshot.data ?? false;

        if (hasPro) {
          return child; // User has Pro - show content
        }

        // User needs Pro - show upgrade prompt
        return showFullScreen
            ? _buildFullScreenPrompt(context)
            : _buildInlinePrompt(context);
      },
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 48),
          const SizedBox(height: 16),
          const Text('Please sign in to access this feature'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildInlinePrompt(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primary.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Pro Feature',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$featureName is exclusive to Pro members',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showIAP(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Unlock Pro'),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenPrompt(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(featureName),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Unlock $featureName',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'This is a Pro feature. Upgrade to unlock unlimited access.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => _showIAP(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Upgrade to Pro',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showIAP(BuildContext context) async {
    final iapService = Provider.of<IAPService?>(
      context,
      listen: false,
    );

    if (iapService == null) return;

    try {
      // For simplicity, we'll navigate to the subscription screen
      // In a real app, you might show a product selection dialog
      if (context.mounted) {
        Navigator.of(context).pushNamed('/subscription');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Simple button widget that checks Pro access before executing action
class ProActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final String featureName;
  final ButtonStyle? style;

  const ProActionButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.featureName,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkProAccess(context),
      builder: (context, snapshot) {
        final hasPro = snapshot.data ?? false;

        return ElevatedButton(
          onPressed: () {
            if (hasPro) {
              onPressed();
            } else {
              _showPaywallThenExecute(context);
            }
          },
          style: style,
          child: child,
        );
      },
    );
  }

  Future<bool> _checkProAccess(BuildContext context) async {
    final service = Provider.of<IAPService?>(context, listen: false);
    return await service?.hasProAccess() ?? false;
  }

  Future<void> _showPaywallThenExecute(BuildContext context) async {
    final service = Provider.of<IAPService?>(context, listen: false);
    if (service == null) return;

    try {
      // Navigate to subscription screen instead of showing paywall
      if (context.mounted) {
        Navigator.of(context).pushNamed('/subscription');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Badge widget to mark Pro features in UI
class ProBadge extends StatelessWidget {
  final bool showLabel;

  const ProBadge({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium, size: 16, color: Colors.white),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              'PRO',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
