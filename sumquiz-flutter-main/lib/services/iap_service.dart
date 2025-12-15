import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// IAP Service for handling Play Store purchases
/// Replaces RevenueCat with direct Play Store integration
class IAPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _proMonthlyId = 'sumquiz_pro_monthly';
  static const String _proYearlyId = 'sumquiz_pro_yearly';
  static const String _proLifetimeId = 'sumquiz_pro_lifetime';

  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final Set<String> _productIds = {
    _proMonthlyId,
    _proYearlyId,
    _proLifetimeId,
  };

  /// Initialize IAP service
  Future<void> initialize() async {
    try {
      // Check if IAP is available
      final isAvailable = await InAppPurchase.instance.isAvailable();
      if (!isAvailable) {
        developer.log('IAP is not available on this device',
            name: 'IAPService');
        return;
      }

      // Listen to purchase updates
      _subscription = InAppPurchase.instance.purchaseStream.listen(
        _listenToPurchaseUpdates,
        onDone: () => _subscription.cancel(),
        onError: (error) {
          developer.log('Purchase stream error: $error',
              name: 'IAPService', error: error);
        },
      );

      // Query product details
      await _getProductDetails();

      developer.log('IAP service initialized successfully', name: 'IAPService');
    } catch (e) {
      developer.log('Failed to initialize IAP service',
          name: 'IAPService', error: e);
    }
  }

  /// Get product details from the store
  Future<List<ProductDetails>> _getProductDetails() async {
    try {
      final response =
          await InAppPurchase.instance.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        developer.log('Products not found: ${response.notFoundIDs}',
            name: 'IAPService');
      }

      return response.productDetails;
    } catch (e) {
      developer.log('Failed to get product details',
          name: 'IAPService', error: e);
      return [];
    }
  }

  /// Listen to purchase updates
  void _listenToPurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      _handlePurchaseUpdate(purchaseDetails);
    }
  }

  /// Handle purchase update
  Future<void> _handlePurchaseUpdate(PurchaseDetails purchaseDetails) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      if (purchaseDetails.status == PurchaseStatus.purchased) {
        // Handle successful purchase
        await _handleSuccessfulPurchase(uid, purchaseDetails);

        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        developer.log('Purchase error: ${purchaseDetails.error}',
            name: 'IAPService');
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        developer.log('Purchase canceled', name: 'IAPService');
      }
    } catch (e) {
      developer.log('Error handling purchase update',
          name: 'IAPService', error: e);
    }
  }

  /// Handle successful purchase
  Future<void> _handleSuccessfulPurchase(
      String uid, PurchaseDetails purchaseDetails) async {
    try {
      // Determine subscription details
      DateTime? expiryDate;
      bool isLifetime = false;

      if (purchaseDetails.productID == _proLifetimeId) {
        isLifetime = true;
      } else {
        // For recurring subscriptions, set expiry to 1 month or 1 year from now
        final now = DateTime.now();
        if (purchaseDetails.productID == _proMonthlyId) {
          expiryDate = now.add(const Duration(days: 30));
        } else if (purchaseDetails.productID == _proYearlyId) {
          expiryDate = now.add(const Duration(days: 365));
        }
      }

      // Update user document in Firestore
      await _firestore.collection('users').doc(uid).set({
        'isPro': true,
        'subscriptionExpiry': expiryDate != null
            ? Timestamp.fromDate(expiryDate)
            : null, // null for lifetime
        'currentProduct': purchaseDetails.productID,
        'lastVerified': FieldValue.serverTimestamp(),
        'purchaseToken':
            purchaseDetails.verificationData.serverVerificationData,
      }, SetOptions(merge: true));

      developer.log('Successfully updated user subscription status for $uid',
          name: 'IAPService');
    } catch (e) {
      developer.log('Failed to update user subscription status',
          name: 'IAPService', error: e);
    }
  }

  /// Purchase a product
  Future<bool> purchaseProduct(String productId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      // Get product details
      final products = await _getProductDetails();
      final product = products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found: $productId'),
      );

      // Make purchase
      final purchaseParam = PurchaseParam(productDetails: product);
      final response = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      return response;
    } catch (e) {
      developer.log('Failed to purchase product: $productId',
          name: 'IAPService', error: e);
      return false;
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // On Android, we need to consume purchases to restore them
        // This is typically handled by querying past purchases
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        // For Android, we would typically verify with Google Play Billing
        // This is a simplified implementation
        developer.log('Restore purchases requested for Android',
            name: 'IAPService');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await InAppPurchase.instance.restorePurchases();
      }
    } catch (e) {
      developer.log('Failed to restore purchases',
          name: 'IAPService', error: e);
    }
  }

  /// Check if user has Pro access
  Future<bool> hasProAccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check email verification
      if (!user.emailVerified) {
        developer.log('User email not verified, blocking Pro access',
            name: 'IAPService');
        return false;
      }

      // Check Firestore for subscription status
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null ||
          !data.containsKey('isPro') ||
          !(data['isPro'] as bool)) {
        return false;
      }

      // Check expiration
      if (data.containsKey('subscriptionExpiry')) {
        if (data['subscriptionExpiry'] == null) {
          // Lifetime access
          return true;
        }

        final expiryDate = (data['subscriptionExpiry'] as Timestamp).toDate();
        return expiryDate.isAfter(DateTime.now());
      }

      return false;
    } catch (e) {
      developer.log('Failed to check Pro access', name: 'IAPService', error: e);
      return false;
    }
  }

  /// Stream Pro status from Firestore
  Stream<bool> isProStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data() as Map<String, dynamic>;

      // Check for 'subscriptionExpiry' field
      if (data.containsKey('subscriptionExpiry')) {
        // Lifetime access is handled by a null expiry date
        if (data['subscriptionExpiry'] == null) return true;

        final expiryDate = (data['subscriptionExpiry'] as Timestamp).toDate();
        return expiryDate.isAfter(DateTime.now());
      }
      return false;
    }).handleError((error) {
      developer.log('Error in isProStream: $error',
          name: 'IAPService', error: error);
      return false;
    });
  }

  /// Get available products
  Future<List<ProductDetails>> getAvailableProducts() async {
    return await _getProductDetails();
  }

  /// Dispose resources
  void dispose() {
    _subscription.cancel();
    developer.log('IAPService disposed', name: 'IAPService');
  }
}
