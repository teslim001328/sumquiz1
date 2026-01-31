import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/web_payment_service.dart';
import 'package:sumquiz/providers/subscription_provider.dart';
import 'package:sumquiz/views/widgets/web/beta_access_dialog.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  ProductDetails? _selectedProduct;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      List<ProductDetails> products = [];

      if (kIsWeb) {
        // Web Flow
        products = await WebPaymentService().getAvailableProducts();
      } else {
        // Mobile Flow
        final iapService = context.read<IAPService?>();
        if (iapService != null) {
          products = await iapService.getAvailableProducts();
        }
      }

      // If still empty on mobile, provide fallback informational products
      if (products.isEmpty && !kIsWeb) {
        products = [
          _FallbackProductDetails(
            id: 'daily_pass',
            title: 'Daily Pass',
            description: '24 hours unlimited access',
            price: 'US\$0.99',
            rawPrice: 0.99,
          ),
          _FallbackProductDetails(
            id: 'weekly_pass',
            title: 'Weekly Pass',
            description: '7 days unlimited access',
            price: 'US\$3.99',
            rawPrice: 3.99,
          ),
          _FallbackProductDetails(
            id: 'monthly_subscription',
            title: 'Monthly Pro',
            description: 'Standard monthly plan',
            price: 'US\$9.99',
            rawPrice: 9.99,
          ),
          _FallbackProductDetails(
            id: 'yearly_subscription',
            title: 'Annual Pro',
            description: 'Best value annual plan',
            price: 'US\$59.99',
            rawPrice: 59.99,
          ),
          _FallbackProductDetails(
            id: 'lifetime_access',
            title: 'Lifetime',
            description: 'One-time payment',
            price: 'US\$129.99',
            rawPrice: 129.99,
          ),
        ];
      }

      // Sort: Monthly < Yearly < Lifetime
      products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

      if (mounted) {
        setState(() {
          _products = products;
          _setDefaultSelection();
        });
      }
    } catch (e) {
      // Error handling is now managed by SubscriptionProvider
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

    final subscriptionProvider = context.read<SubscriptionProvider>();

    bool success;

    if (kIsWeb) {
      // Web Payment Redirect to Mobile Beta
      // NOTE: Web payments are temporarily disabled in favor of mobile app beta access
      /*
      final user = context.read<UserModel?>();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to make a purchase'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check if FlutterWave is configured
      if (!WebPaymentService.isConfigured) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Payment system not configured. Please contact support.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final result = await WebPaymentService().processWebPurchase(
        context: context,
        product: _selectedProduct!,
        user: user,
      );

      if (result.success && mounted) {
        // Show "Processing payment..." dialog
        _showProcessingDialog(context, user.uid);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Payment failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
      */

      // Show Beta Access Dialog instead
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => const BetaAccessDialog(),
        );
      }
    } else {
      // Mobile Payment Flow
      success =
          await subscriptionProvider.purchaseProduct(_selectedProduct!.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upgrade Successful!'),
              backgroundColor: Colors.green,
            ),
          );
          // Give user time to see success message
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subscriptionProvider = context.watch<SubscriptionProvider>();

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
      body: subscriptionProvider.isLoading
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
                            'Master Your Exams',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Identify what matters, test your knowledge, \nand retain everything forever.',
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
                                _buildFeatureRow(
                                    'Unlimited AI Summaries & Quizzes',
                                    isUnlocked: true,
                                    theme: theme),
                                _buildFeatureRow(
                                    'Import from YouTube & Web Articles',
                                    isUnlocked: true,
                                    theme: theme),
                                _buildFeatureRow(
                                    'Export PDF (Summary, Quiz, Flashcards)',
                                    isUnlocked: true,
                                    theme: theme),
                                _buildFeatureRow(
                                    'Unlimited Spaced Repetition Review',
                                    isUnlocked: true,
                                    theme: theme),
                                _buildFeatureRow('Offline Access & Cloud Sync',
                                    isUnlocked: true, theme: theme),
                                _buildFeatureRow(
                                    'Creator Dashboard & Publishing',
                                    isUnlocked: true,
                                    theme: theme),
                                _buildFeatureRow('Advanced Study Analytics',
                                    isUnlocked: true, theme: theme),
                                _buildFeatureRow('Priority Support',
                                    isUnlocked: true, theme: theme),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Quick Access Passes Section (NEW)
                          _buildQuickAccessSection(theme, isDark),

                          const SizedBox(height: 32),

                          // Divider with "OR SUBSCRIBE" text
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color:
                                      theme.dividerColor.withValues(alpha: 0.3),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR SUBSCRIBE',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color:
                                      theme.dividerColor.withValues(alpha: 0.3),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Products List (filter out passes) - Yearly pre-selected
                          ..._products
                              .where((p) =>
                                  !p.id.contains('daily') &&
                                  !p.id.contains('weekly'))
                              .map((product) =>
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
                            onPressed: _selectedProduct != null &&
                                    !subscriptionProvider.isLoading
                                ? _buyProduct
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: subscriptionProvider.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : _selectedProduct != null
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
                                          '🎁 Invite friends and earn free Pro time'),
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
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.amber[600]!, Colors.orange[400]!],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'POPULAR',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
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

  Widget _buildQuickAccessSection(ThemeData theme, bool isDark) {
    final passes = _products
        .where((p) => p.id.contains('daily') || p.id.contains('weekly'))
        .toList();

    if (passes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on, color: Colors.amber[700], size: 20),
            const SizedBox(width: 8),
            Text(
              'Quick Access',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Need access now? Get instant unlimited access!',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: passes
              .map((pass) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: passes.indexOf(pass) == 0 ? 8 : 0,
                        left: passes.indexOf(pass) == 1 ? 8 : 0,
                      ),
                      child: _buildPassCard(pass, theme, isDark),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPassCard(ProductDetails pass, ThemeData theme, bool isDark) {
    final isDailyPass = pass.id.contains('daily');
    final isSelected = _selectedProduct?.id == pass.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedProduct = pass),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                    Colors.amber.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              isDailyPass ? Icons.timer : Icons.calendar_today,
              color: isSelected ? theme.colorScheme.primary : Colors.amber[700],
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              isDailyPass ? 'Daily Pass' : 'Weekly Pass',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pass.price,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isDailyPass ? '24 hours' : '7 days',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*
  void _showProcessingDialog(BuildContext context, String uid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StreamBuilder<bool>(
          stream: WebPaymentService().watchPremiumStatus(uid),
          builder: (context, snapshot) {
            final isPremium = snapshot.data ?? false;

            if (isPremium) {
              // Automatically close dialog and screen on success
              Future.delayed(const Duration(milliseconds: 500), () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context); // Close dialog
                  context.pop(); // Close subscription screen
                }
              });

              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 64),
                    const SizedBox(height: 16),
                    Text('Payment Successful!',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Your premium features are now unlocked.'),
                  ],
                ),
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text('Processing Payment...',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  const Text(
                    'We are waiting for confirmation from the payment provider. This usually takes a few seconds.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Wait in background'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  */

  String _getProductTitle(String id) {
    if (id.contains('daily')) return 'Daily';
    if (id.contains('weekly')) return 'Weekly';
    if (id.contains('monthly')) return 'Monthly';
    if (id.contains('yearly')) return 'Annual';
    if (id.contains('lifetime')) return 'Lifetime';
    return 'Standard';
  }

  String _getPeriod(String id) {
    if (id.contains('daily')) return 'day';
    if (id.contains('weekly')) return 'wk';
    if (id.contains('monthly')) return 'mo';
    if (id.contains('yearly')) return 'yr';
    return '';
  }

  String _getBillingText(String id) {
    if (id.contains('daily')) return 'Access for 24 hours';
    if (id.contains('weekly')) return 'Access for 7 days';
    if (id.contains('monthly')) return 'Billed monthly';
    if (id.contains('yearly')) return 'Save ~US\$10/month';
    if (id.contains('lifetime')) return 'One-time payment';
    return '';
  }

  Widget _buildAlreadyProView(BuildContext context, ThemeData theme) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final user = context.watch<UserModel?>();

    String statusText = 'Pro Member';
    String? expiryText;
    IconData statusIcon = Icons.check_circle_rounded;
    Color statusColor = theme.colorScheme.primary;

    if (user != null) {
      if (user.isCreatorPro) {
        statusText = 'Creator Pro';
        statusIcon = Icons.workspace_premium;
        statusColor = Colors.purple;
      } else if (user.isTrial) {
        statusText = 'Trial Member';
        statusIcon = Icons.timelapse;
        statusColor = Colors.orange;
        expiryText =
            'Trial ends in ${subscriptionProvider.getFormattedExpiry()}';
      } else if (subscriptionProvider.subscriptionExpiry != null) {
        expiryText = 'Expires in ${subscriptionProvider.getFormattedExpiry()}';
        if (subscriptionProvider.isExpiringSoon()) {
          statusText = 'Pro (Expiring Soon)';
          statusColor = Colors.orange;
        }
      } else {
        // Lifetime access
        expiryText = 'Lifetime access';
      }
    }

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
            Icon(statusIcon, color: statusColor, size: 80),
            const SizedBox(height: 24),
            Text(
              statusText,
              style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              'Thank you for supporting SumQuiz.',
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            if (expiryText != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  expiryText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (!user!.isCreatorPro &&
                !user
                    .isTrial) // Only show restore button for regular subscribers
              OutlinedButton.icon(
                onPressed: () async {
                  await subscriptionProvider.restorePurchases();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Purchases restored successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.restore),
                label: const Text('Restore Purchases'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fallback product details for when the store is offline
class _FallbackProductDetails implements ProductDetails {
  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final String price;
  @override
  final double rawPrice;
  @override
  final String currencyCode = 'USD';
  @override
  final String currencySymbol = '\$';

  _FallbackProductDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rawPrice,
  });
}
