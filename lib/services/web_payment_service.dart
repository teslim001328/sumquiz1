import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WebPaymentResult {
  final bool success;
  final String? errorMessage;
  final String? checkoutUrl;

  WebPaymentResult(
      {required this.success, this.errorMessage, this.checkoutUrl});
}

class WebPaymentService {
  // Load API key from environment variables
  static String get publicKey {
    // Load from .env file
    final key = dotenv.env['FLUTTERWAVE_PUBLIC_KEY'] ??
        'YOUR_FLUTTERWAVE_PUBLIC_KEY_HERE';

    if (key == 'YOUR_FLUTTERWAVE_PUBLIC_KEY_HERE') {
      // Fallback - you need to provide your actual key
      throw Exception(
          'FlutterWave public key not configured. Please add FLUTTERWAVE_PUBLIC_KEY to your .env file');
    }
    return key;
  }

  static const String appName = "SumQuiz Pro";
  static const String currency = "USD";

  /// Check if FlutterWave is properly configured
  static bool get isConfigured {
    try {
      final key = publicKey;
      return key != 'YOUR_FLUTTERWAVE_PUBLIC_KEY_HERE' &&
          key.startsWith('FLWPUBK-');
    } catch (e) {
      return false;
    }
  }

  /// Validate that FlutterWave is ready for payments
  static void validateConfiguration() {
    if (!isConfigured) {
      throw Exception('FlutterWave is not properly configured. \n'
          'Please:\n'
          '1. Get your API keys from https://dashboard.flutterwave.com/settings/apis\n'
          '2. Add FLUTTERWAVE_PUBLIC_KEY to your .env file\n'
          '3. Restart the app');
    }
  }

  /// Centralized Product Definitions for Web
  static final List<ProductDetails> webProducts = [
    // Quick Access Passes
    ProductDetails(
      id: 'sumquiz_daily_pass',
      title: 'Daily Pass',
      description: 'Unlimited access for 24 hours',
      price: r'\$0.99',
      rawPrice: 0.99,
      currencyCode: 'USD',
    ),
    ProductDetails(
      id: 'sumquiz_weekly_pass',
      title: 'Weekly Pass',
      description: 'Unlimited access for 7 days',
      price: r'\$4.99',
      rawPrice: 4.99,
      currencyCode: 'USD',
    ),
    // Subscription Plans
    ProductDetails(
      id: 'sumquiz_pro_monthly',
      title: 'SumQuiz Pro Monthly',
      description: 'Monthly Subscription',
      price: r'\$14.99',
      rawPrice: 14.99,
      currencyCode: 'USD',
    ),
    ProductDetails(
      id: 'sumquiz_pro_yearly',
      title: 'SumQuiz Pro Annual',
      description: 'Annual Subscription',
      price: r'\$99.00',
      rawPrice: 99.00,
      currencyCode: 'USD',
    ),
    ProductDetails(
      id: 'sumquiz_pro_lifetime',
      title: 'SumQuiz Pro Lifetime',
      description: 'Lifetime Access',
      price: r'\$249.99',
      rawPrice: 249.99,
      currencyCode: 'USD',
    ),
  ];

  Future<List<ProductDetails>> getAvailableProducts() async {
    // Simulate network delay if needed, or just return static list
    await Future.delayed(const Duration(milliseconds: 500));
    return webProducts;
  }

  /// Process the entire Web Purchase flow: Redirect to Cloud Function generated link
  Future<WebPaymentResult> processWebPurchase({
    required BuildContext context,
    required ProductDetails product,
    required UserModel user,
  }) async {
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('createPayment');

      final result = await callable.call({
        'amount': product.rawPrice,
        'currency': currency,
        'email': user.email,
        'name': user.displayName,
        'productId': product.id,
      });

      final checkoutUrl = result.data['checkoutUrl'] as String?;

      if (checkoutUrl != null) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return WebPaymentResult(success: true, checkoutUrl: checkoutUrl);
        } else {
          return WebPaymentResult(
            success: false,
            errorMessage: 'Could not launch payment URL',
          );
        }
      } else {
        return WebPaymentResult(
          success: false,
          errorMessage: 'Failed to generate payment link',
        );
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      return WebPaymentResult(
        success: false,
        errorMessage: 'Payment Error: $e',
      );
    }
  }

  /// Listen for premium status change (used for the "Processing payment..." screen)
  Stream<bool> watchPremiumStatus(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      // Check both fields for robustness
      return (data['isPremium'] == true) || (data['isPro'] == true);
    });
  }
}
