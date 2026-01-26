import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:uuid/uuid.dart';

class WebPaymentResult {
  final bool success;
  final String? errorMessage;
  final String? transactionId;

  WebPaymentResult(
      {required this.success, this.errorMessage, this.transactionId});
}

class WebPaymentService {
  // TODO: Replace with your actual Public Key from Flutterwave Dashboard
  static const String publicKey = "FLWPUBK_TEST-SANDBOX-DEMO-DUMMY";
  static const String appName = "SumQuiz Pro";
  static const String currency = "USD";

  /// Centralized Product Definitions for Web
  static final List<ProductDetails> webProducts = [
    // Quick Access Passes (NEW)
    ProductDetails(
      id: 'sumquiz_exam_24h',
      title: 'Exam Pass (24h)',
      description: 'Unlimited access for 24 hours',
      price: '\$2.99',
      rawPrice: 2.99,
      currencyCode: 'USD',
    ),
    ProductDetails(
      id: 'sumquiz_week_pass',
      title: 'Week Pass',
      description: 'Unlimited access for 7 days',
      price: '\$3.99',
      rawPrice: 3.99,
      currencyCode: 'USD',
    ),
    // Subscription Plans
    ProductDetails(
      id: 'sumquiz_pro_monthly',
      title: 'SumQuiz Pro Monthly',
      description: 'Monthly Subscription',
      price: '\$4.99',
      rawPrice: 4.99,
      currencyCode: 'USD',
    ),
    ProductDetails(
      id: 'sumquiz_pro_yearly',
      title: 'SumQuiz Pro Annual',
      description: 'Annual Subscription',
      price: '\$39.99',
      rawPrice: 39.99,
      currencyCode: 'USD',
    ),
    ProductDetails(
      id: 'sumquiz_pro_lifetime',
      title: 'SumQuiz Pro Lifetime',
      description: 'Lifetime Access',
      price: '\$99.99',
      rawPrice: 99.99,
      currencyCode: 'USD',
    ),
  ];

  Future<List<ProductDetails>> getAvailableProducts() async {
    // Simulate network delay if needed, or just return static list
    await Future.delayed(const Duration(milliseconds: 500));
    return webProducts;
  }

  /// Process the entire Web Purchase flow: Payment -> Verification -> Upgrade
  Future<WebPaymentResult> processWebPurchase({
    required BuildContext context,
    required ProductDetails product,
    required UserModel user,
  }) async {
    final email = user.email.isNotEmpty ? user.email : 'customer@sumquiz.app';
    final name =
        user.displayName.isNotEmpty ? user.displayName : 'Valued Customer';
    final txRef = "sumquiz_${const Uuid().v4()}";

    // 1. Initialize Flutterwave Charge
    final customer = Customer(
      name: name,
      phoneNumber: "0000000000",
      email: email,
    );

    final flutterwave = Flutterwave(
      publicKey: publicKey,
      currency: currency,
      redirectUrl: "https://sumquiz.web.app",
      txRef: txRef,
      amount: product.rawPrice.toString(),
      customer: customer,
      paymentOptions: "card, payattitude, barter, bank transfer, ussd",
      customization: Customization(title: appName),
      isTestMode: true,
    );

    try {
      final ChargeResponse response = await flutterwave.charge(context);

      if (response.success == true) {
        // 2. Determine Duration based on product
        Duration? duration;
        if (product.id.contains('24h')) {
          duration = const Duration(hours: 24); // Exam Pass
        } else if (product.id.contains('week')) {
          duration = const Duration(days: 7); // Week Pass
        } else if (product.id.contains('monthly')) {
          duration = const Duration(days: 30);
        } else if (product.id.contains('yearly')) {
          duration = const Duration(days: 365);
        }
        // Lifetime: duration is null

        // 3. Upgrade User - Update Firestore directly
        final expiryDate =
            duration != null ? DateTime.now().add(duration) : null;

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'subscriptionExpiry':
              expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
          'isTrial': false,
          'currentProduct': product.id,
          'lastVerified': FieldValue.serverTimestamp(),
          'transactionId': response.transactionId,
        }, SetOptions(merge: true));

        return WebPaymentResult(
          success: true,
          transactionId: response.transactionId,
        );
      } else {
        return WebPaymentResult(
          success: false,
          errorMessage: 'Payment Cancelled or Failed',
        );
      }
    } catch (e) {
      return WebPaymentResult(
        success: false,
        errorMessage: 'Payment Error: $e',
      );
    }
  }
}
