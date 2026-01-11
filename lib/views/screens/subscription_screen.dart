import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/web_payment_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  ProductDetails? _selectedProduct;
  List<ProductDetails> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final isWeb = Theme.of(context).platform != TargetPlatform.android &&
        Theme.of(context).platform != TargetPlatform.iOS;

    List<ProductDetails> products = [];

    if (isWeb) {
      // Web Flow
      products = await WebPaymentService().getAvailableProducts();
    } else {
      // Mobile Flow
      final iapService = context.read<IAPService?>();
      if (iapService != null) {
        products = await iapService.getAvailableProducts();
      }
    }

    // Sort: Monthly < Yearly < Lifetime
    products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

    if (mounted) {
      setState(() {
        _products = products;
        _setDefaultSelection();
        _isLoading = false;
      });
    }
  }

  void _setDefaultSelection() {
    if (_products.isNotEmpty) {
      _selectedProduct = _products.firstWhere((p) => p.id.contains('yearly'),
          orElse: () => _products.length > 1 ? _products[1] : _products.first);
    }
  }

  Future<void> _buyProduct() async {
    if (_selectedProduct == null) return;
    setState(() => _isLoading = true);

    final isWeb = Theme.of(context).platform != TargetPlatform.android &&
        Theme.of(context).platform != TargetPlatform.iOS;

    try {
      if (isWeb) {
        // Web Payment Flow
        final user = context.read<UserModel?>();
        if (user == null) {
          throw Exception('User not logged in');
        }

        final result = await WebPaymentService().processWebPurchase(
          context: context,
          product: _selectedProduct!,
          user: user,
        );

        if (mounted) {
          if (result.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Upgrade Successful! Refreshing...'),
                backgroundColor: Colors.green,
              ),
            );
            // Optional: Delay to let user see the checkmark or confetti
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) context.pop(); // Go back to main/home
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.errorMessage ?? 'Payment Failed'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Mobile Payment Flow
        final iapService = context.read<IAPService?>();
        if (iapService != null) {
          await iapService.purchaseProduct(_selectedProduct!.id);
          // Note: Mobile IAP flow is async via stream listener in previous setup.
          // We might want to show some "Processing..." UI until stream updates.
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Check if user is already Pro
    final user = context.watch<UserModel?>();
    if (user != null && user.isPro) {
      return _buildAlreadyProView(context, theme);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child:
                  CircularProgressIndicator(color: theme.colorScheme.primary))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Header
                          const SizedBox(height: 10),
                          Icon(Icons.bolt_rounded,
                              color: theme.colorScheme.primary, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Unlock SumQuiz Pro',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Supercharge your learning with unlimited access.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 48),

                          // Features List
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: theme.dividerColor
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              children: [
                                _buildFeatureRow('Unlimited content generation',
                                    isUnlocked: true, theme: theme),
                                _buildFeatureRow('Unlimited folders & decks',
                                    isUnlocked: true, theme: theme),
                                _buildFeatureRow('Smart Spaced Repetition',
                                    isUnlocked: true, theme: theme),
                                _buildFeatureRow('Offline access & Sync',
                                    isUnlocked: true, theme: theme),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Products List
                          ..._products.map((product) =>
                              _buildProductCard(product, theme, isDark)),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Section
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        border: Border(
                            top: BorderSide(
                                color: theme.dividerColor
                                    .withValues(alpha: 0.5)))),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                _selectedProduct != null ? _buyProduct : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _selectedProduct != null
                                ? Text(
                                    'Start ${_getProductTitle(_selectedProduct!.id)} Plan',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ))
                                : const Text('Select a Plan'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => context.push('/referral'),
                          child: RichText(
                            text: TextSpan(
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5)),
                                children: const [
                                  TextSpan(
                                      text:
                                          'Invite 3 friends and get 1 week of Pro free 🎁'),
                                ]),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureRow(String label,
      {required bool isUnlocked, required ThemeData theme}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

  Widget _buildProductCard(
      ProductDetails product, ThemeData theme, bool isDark) {
    final isSelected = _selectedProduct?.id == product.id;
    final isBestValue = product.id.contains('yearly');

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProduct = product;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.05)
              : theme.cardColor,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.5),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_getProductTitle(product.id),
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface)),
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'BEST VALUE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.black, // Always black on amber
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        )
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getBillingText(product.id),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(product.price,
                    style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface)),
                if (!product.id.contains('lifetime'))
                  Text(
                    '/${_getPeriod(product.id)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getProductTitle(String id) {
    if (id.contains('monthly')) return 'Monthly';
    if (id.contains('yearly')) return 'Annual';
    if (id.contains('lifetime')) return 'Lifetime';
    return 'Standard';
  }

  String _getPeriod(String id) {
    if (id.contains('monthly')) return 'mo';
    if (id.contains('yearly')) return 'yr';
    return '';
  }

  String _getBillingText(String id) {
    if (id.contains('monthly')) return 'Flexible cancellation';
    if (id.contains('yearly')) return 'Save 33%';
    if (id.contains('lifetime')) return 'One-time payment';
    return '';
  }

  Widget _buildAlreadyProView(BuildContext context, ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: theme.colorScheme.primary, size: 80),
            const SizedBox(height: 24),
            Text(
              'You are a Pro Member!',
              style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              'Thank you for supporting SumQuiz.',
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
