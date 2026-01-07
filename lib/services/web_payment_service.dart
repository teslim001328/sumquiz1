import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/user_service.dart';
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
      context: context,
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
      final ChargeResponse response = await flutterwave.charge();

      if (response != null && response.success == true) {
        // 2. Determine Duration
        Duration? duration;
        if (product.id.contains('monthly')) duration = const Duration(days: 30);
        if (product.id.contains('yearly')) duration = const Duration(days: 365);
        // Lifetime: duration is null

        // 3. Upgrade User
        await UserService().upgradeToPro(user.uid, duration: duration);

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
