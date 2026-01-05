import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:uuid/uuid.dart';

class WebPaymentService {
  // TODO: Replace with your actual Public Key from Flutterwave Dashboard
  // Use Test Key for development: FLWPUBK_TEST-...
  static const String publicKey = "FLWPUBK_TEST-SANDBOX-DEMO-DUMMY";

  // Product configurations
  static const String appName = "SumQuiz Pro";
  static const String currency = "USD";

  // Example Price Map (You might want to fetch this or keep it synced with IAP)
  static const Map<String, double> prices = {
    'sumquiz_pro_monthly': 4.99,
    'sumquiz_pro_yearly': 39.99,
    'sumquiz_pro_lifetime': 99.99,
  };

  /// handlePaymentInitialization
  /// Returns true if payment was successful, false otherwise
  Future<bool> handlePaymentInitialization({
    required BuildContext context,
    required String email,
    required String fullName,
    required String phoneNumber,
    required String productId,
  }) async {
    final price = prices[productId] ?? 4.99;
    final txRef = "sumquiz_${const Uuid().v4()}";

    final Customer customer = Customer(
      name: fullName,
      phoneNumber: phoneNumber,
      email: email,
    );

    final Flutterwave flutterwave = Flutterwave(
      publicKey: publicKey,
      currency: currency,
      redirectUrl: "https://sumquiz.web.app", // Your redirect URL
      txRef: txRef,
      amount: price.toString(),
      customer: customer,
      paymentOptions: "card, payattitude, barter, bank transfer, ussd",
      customization: Customization(title: appName),
      isTestMode: true, // TODO: Toggle based on environment
    );

    try {
      final ChargeResponse response = await flutterwave.charge(context);

      if (response.success == true) {
        // Flutterwave docs say check for 'success' or transaction id
        debugPrint("Payment Successful: ${response.transactionId}");
        return true;
      } else {
        debugPrint("Payment Failed or Cancelled");
        return false;
      }
    } catch (e) {
      debugPrint("Payment Error: $e");
      return false;
    }
  }
}
