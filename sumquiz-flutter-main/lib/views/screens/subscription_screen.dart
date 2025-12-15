import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../services/iap_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

/// Modern subscription screen using RevenueCat native paywalls
/// This is a wrapper that presents the RevenueCat paywall
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<UserModel?>();
    final iapService = context.watch<IAPService?>();
    final authUser = FirebaseAuth.instance.currentUser;
    final isVerified = authUser?.emailVerified ?? false;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('SumQuiz Pro'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (authUser != null && !isVerified)
            _buildVerificationWarning(context, theme),
          Expanded(
            child: Center(
              child: FutureBuilder<bool>(
                future: _checkProStatus(iapService),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  final hasPro = snapshot.data ?? user?.isPro ?? false;

                  if (hasPro) {
                    // User already has Pro - show subscription management
                    return _buildProMemberView(
                        context, theme, iapService);
                  }

                  // User needs to subscribe - show paywall button
                  return _buildUpgradeView(context, theme, iapService);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkProStatus(IAPService? service) async {
    if (service == null) return false;
    return await service.hasProAccess();
  }

  Widget _buildUpgradeView(
    BuildContext context,
    ThemeData theme,
    IAPService? iapService,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Unlock SumQuiz Pro',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Get unlimited access to all features',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.hintColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Feature list
          _buildFeatureItem(theme, 'Unlimited quizzes & flashcards'),
          _buildFeatureItem(theme, 'AI-powered question generation'),
          _buildFeatureItem(theme, 'Advanced progress tracking'),
          _buildFeatureItem(theme, 'Ad-free experience'),

          const SizedBox(height: 48),

          // Show IAP Purchase Button
          ElevatedButton(
            onPressed: () => _showIAPProducts(context, iapService),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'View Plans',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Restore Purchases
          TextButton(
            onPressed: () => _restorePurchases(context, iapService),
            child: Text(
              'Restore Purchases',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProMemberView(
    BuildContext context,
    ThemeData theme,
    IAPService? iapService,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified,
            size: 80,
            color: Colors.amber,
          ),
          const SizedBox(height: 24),
          Text(
            'You\'re a Pro Member!',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Enjoy unlimited access to all features',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.hintColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Show subscription details
          FutureBuilder<List<ProductDetails>?>(
            future: iapService?.getAvailableProducts(),
            builder: (context, snapshot) {
              final products = snapshot.data;

              if (products == null || products.isEmpty) {
                return const SizedBox.shrink();
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Products',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...products.map((product) => _buildProductRow(theme, product)).toList(),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Manage Subscription (IAP Management)
          ElevatedButton(
            onPressed: () =>
                _presentIAPManagement(context, iapService),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Manage Subscription',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 22, color: Colors.green.shade500),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.hintColor,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProductRow(ThemeData theme, ProductDetails product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          product.description,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          product.price,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const Divider(),
      ],
    );
  }

  /// Show IAP products for purchase
  Future<void> _showIAPProducts(
    BuildContext context,
    IAPService? iapService,
  ) async {
    if (iapService == null) {
      _showError(context, 'IAP service not available');
      return;
    }

    try {
      final products = await iapService.getAvailableProducts();
      
      if (!context.mounted) return;
      
      if (products.isEmpty) {
        _showError(context, 'No products available');
        return;
      }
      
      // Show product selection dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose a Plan'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: products.map((product) => ListTile(
                title: Text(product.title),
                subtitle: Text(product.description),
                trailing: Text(product.price),
                onTap: () async {
                  Navigator.of(context).pop();
                  final success = await iapService.purchaseProduct(product.id);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Welcome to SumQuiz Pro! 🎉'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              )).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to load products: $e');
      }
    }
  }

  /// Present IAP management options
  Future<void> _presentIAPManagement(
    BuildContext context,
    IAPService? iapService,
  ) async {
    if (iapService == null) {
      _showError(context, 'IAP service not available');
      return;
    }

    // For now, just show a simple dialog with restore option
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Subscription'),
        content: const Text('You can restore your purchases or manage your subscription through the Play Store app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await iapService.restorePurchases();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restore request sent')),
                );
              }
            },
            child: const Text('Restore Purchases'),
          ),
        ],
      ),
    );
  }

  /// Restore previous purchases
  Future<void> _restorePurchases(
    BuildContext context,
    IAPService? iapService,
  ) async {
    if (iapService == null) {
      _showError(context, 'IAP service not available');
      return;
    }

    try {
      await iapService.restorePurchases();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore request sent')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to restore purchases: $e');
      }
    }
  }

  Widget _buildVerificationWarning(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please verify your email to access Pro features.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                try {
                  final authService = context.read<AuthService>();
                  await authService.resendVerificationEmail();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification email sent!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Resend Verification Email'),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
