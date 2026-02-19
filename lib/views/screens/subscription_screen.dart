
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/web_payment_service.dart';
import 'package:sumquiz/providers/subscription_provider.dart';

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
        products = await WebPaymentService().getAvailableProducts();
      } else {
        final iapService = context.read<IAPService?>();
        if (iapService != null) {
          products = await iapService.getAvailableProducts();
        }
      }

      if (products.isEmpty && !kIsWeb) {
        products = [
          _FallbackProductDetails(
            id: 'monthly_plan',
            title: 'Monthly Plan',
            description: 'Standard monthly plan',
            price: '\$5.99',
            rawPrice: 5.99,
          ),
          _FallbackProductDetails(
            id: 'yearly_plan',
            title: 'Yearly Plan',
            description: 'Best value annual plan',
            price: '\$49.00',
            rawPrice: 49.00,
          ),
        ];
      }

      // Filter for only monthly and yearly plans
      products = products
          .where((p) => p.id.contains('monthly') || p.id.contains('yearly'))
          .toList();
      
      // Sort: Monthly < Yearly
      products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

      if (mounted) {
        setState(() {
          _products = products;
          _setDefaultSelection();
        });
      }
    } catch (e) {
      // Error handling
    }
  }

  void _setDefaultSelection() {
    if (_products.isNotEmpty) {
      _selectedProduct = _products.firstWhere(
        (p) => p.id.contains('yearly'),
        orElse: () => _products.first,
      );
    }
  }

  Future<void> _buyProduct() async {
    if (_selectedProduct == null) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();

    if (kIsWeb) {
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

      final result = await WebPaymentService().processWebPurchase(
        context: context,
        product: _selectedProduct!,
        user: user,
      );

      if (mounted && !result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Payment failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      final success =
          await subscriptionProvider.purchaseProduct(_selectedProduct!.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upgrade Successful!'),
              backgroundColor: Colors.green,
            ),
          );
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
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final user = context.watch<UserModel?>();

    if (user != null && user.isPro) {
      return _buildAlreadyProView(context);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F112B),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: subscriptionProvider.isLoading && _products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          _buildHeroSection(),
                          const SizedBox(height: 32),
                          _buildFeaturesList(),
                          const SizedBox(height: 32),
                          ..._products.map((product) => _buildPlanCard(product)),
                          const SizedBox(height: 120), // Space for the floating button
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomSheet(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          Row(
            children: [
              Image.asset('assets/images/sumquiz_logo.png', height: 28),
              const SizedBox(width: 8),
              const Text(
                'SumQuiz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              // Restore purchases logic
            },
            child: const Text(
              'Restore',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: AssetImage('assets/images/onboarding_background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Exam Season Boost',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Pass Exams Faster with AI Power',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Join thousands of students acing their classes with smart summaries and practice.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesList() {
    return const Column(
      children: [
        _FeatureListItem(
          text: 'Unlimited AI Summaries',
          subtext: 'Turn 100 pages into concise notes instantly.',
        ),
        _FeatureListItem(
          text: 'Track Weak Topics',
          subtext: 'Identify knowledge gaps before the test.',
        ),
        _FeatureListItem(
          text: 'Exam Mode Practice',
          subtext: 'Simulate real conditions with AI generated quizzes.',
        ),
      ],
    );
  }
  
  Widget _buildPlanCard(ProductDetails product) {
    final isSelected = _selectedProduct?.id == product.id;
    final isBestValue = product.id.contains('yearly');

    return GestureDetector(
      onTap: () => setState(() => _selectedProduct = product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3D4080) : const Color(0xFF1A1F44),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF474BFF) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isBestValue)
                  const Text('BEST VALUE', style: TextStyle(color: Color(0xFF3D9CFF), fontWeight: FontWeight.bold))
                else 
                   const Text('FLEXIBLE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  product.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isBestValue) ...[
                  const SizedBox(height: 4),
                  const Text('Save 30% compared to monthly', style: TextStyle(color: Color(0xFF3D9CFF)))
                ]
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                 Text(
                  product.price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  product.id.contains('monthly') ? '/month' : '/year',
                  style: const TextStyle(color: Colors.white70),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      color: const Color(0xFF0F112B).withOpacity(0.95),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: _buyProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF474BFF),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Unlock Pro Now',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, color: Colors.white54, size: 14),
              SizedBox(width: 8),
              Text(
                'Secure payment via PLayStore',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('Terms of Service', style: TextStyle(color: Colors.white70)),
              ),
              const Text('|', style: TextStyle(color: Colors.white70)),
              TextButton(
                onPressed: () {},
                child: const Text('Privacy Policy', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyProView(BuildContext context) {
    // Keeping this simple as it's not the focus of the redesign.
    return Scaffold(
      backgroundColor: const Color(0xFF0F112B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 24),
            Text(
              'You are a Pro Member!',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureListItem extends StatelessWidget {
  final String text;
  final String subtext;

  const _FeatureListItem({required this.text, required this.subtext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF474BFF), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtext,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

