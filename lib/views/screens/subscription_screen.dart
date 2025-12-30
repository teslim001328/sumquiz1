import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../services/iap_service.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel?>();
    final iapService = context.watch<IAPService?>();
    final authUser = context.watch<AuthService>().currentUser;
    final isVerified = authUser?.emailVerified ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('SumQuiz Pro',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              if (authUser != null && !isVerified)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildVerificationWarning(context),
                ),
              Expanded(
                child: FutureBuilder<bool>(
                  future: _checkProStatus(iapService),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final hasPro = snapshot.data ?? user?.isPro ?? false;

                    if (hasPro) {
                      return _buildProMemberView(context, iapService);
                    }

                    return _buildUpgradeView(context, iapService);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _checkProStatus(IAPService? service) async {
    return await service?.hasProAccess() ?? false;
  }

  Widget _buildUpgradeView(BuildContext context, IAPService? iapService) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Icon(Icons.workspace_premium_outlined,
              size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Unlock SumQuiz Pro',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text('Get unlimited access to all features',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          const SizedBox(height: 40),
          _buildFeatureList(theme),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _showIAPProducts(context, iapService),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('View Plans',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _restorePurchases(context, iapService),
            child: Text('Restore Purchases',
                style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildProMemberView(BuildContext context, IAPService? iapService) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Icon(Icons.verified, size: 80, color: Colors.amber),
          const SizedBox(height: 24),
          Text('You\'re a Pro Member!',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Enjoy unlimited access to all features',
              style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
            color: theme.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pro Benefits',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildFeatureItem(theme, 'Unlimited content generation'),
                  _buildFeatureItem(theme, 'Unlimited folders'),
                  _buildFeatureItem(theme, 'Unlimited Flashcards'),
                  _buildFeatureItem(theme, 'Offline Access'),
                  _buildFeatureItem(theme, 'Full Spaced Repetition System'),
                  _buildFeatureItem(theme, 'Progress analytics with exports'),
                  _buildFeatureItem(theme, 'Daily missions with full rewards'),
                  _buildFeatureItem(theme, 'All gamification rewards'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FutureBuilder<List<ProductDetails>?>(
            future: iapService?.getAvailableProducts(),
            builder: (context, snapshot) {
              // Only show available products if needed, otherwise hide
              // For Pro members, we might want to just show "Manage Subscription"
              return const SizedBox.shrink();
            },
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () => _presentIAPManagement(context, iapService),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Manage Subscription'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList(ThemeData theme) {
    return Column(
      children: [
        _buildFeatureItem(theme, 'Unlimited content generation (Free: 3/week)'),
        _buildFeatureItem(theme, 'Unlimited folders (Free: 2 max)'),
        _buildFeatureItem(theme, 'Unlimited Flashcards (Free: 50 max)'),
        _buildFeatureItem(theme, 'Offline Access'),
        _buildFeatureItem(theme, 'Full Spaced Repetition System'),
        _buildFeatureItem(theme, 'Progress analytics & exports'),
        _buildFeatureItem(theme, 'Daily missions & rewards'),
      ],
    );
  }

  Widget _buildFeatureItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }

  Future<void> _showIAPProducts(
      BuildContext context, IAPService? iapService) async {
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

      await showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose a Plan',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ...products.map((p) => _buildProductTile(context, p, iapService)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to load products: $e');
    }
  }

  Widget _buildProductTile(
      BuildContext context, ProductDetails product, IAPService iapService) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(product.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(product.description,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20)),
          child: Text(product.price,
              style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold)),
        ),
        onTap: () async {
          Navigator.of(context).pop();
          final success = await iapService.purchaseProduct(product.id);
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Welcome to SumQuiz Pro! 🎉'),
                  backgroundColor: Colors.green),
            );
          }
        },
      ),
    );
  }

  Future<void> _presentIAPManagement(
      BuildContext context, IAPService? iapService) async {
    if (iapService == null) {
      _showError(context, 'IAP service not available');
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Subscription'),
        content: const Text(
            'You can restore purchases or manage your subscription through your device\'s app store.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _restorePurchases(context, iapService);
            },
            child: const Text('Restore Purchases'),
          ),
        ],
      ),
    );
  }

  Future<void> _restorePurchases(
      BuildContext context, IAPService? iapService) async {
    if (iapService == null) {
      _showError(context, 'IAP service not available');
      return;
    }
    try {
      await iapService.restorePurchases();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restore request sent')));
      }
    } catch (e) {
      if (context.mounted)
        _showError(context, 'Failed to restore purchases: $e');
    }
  }

  Widget _buildVerificationWarning(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Please verify your email to access Pro features.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold)),
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Verification email sent!')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showError(context, 'Error: $e');
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
