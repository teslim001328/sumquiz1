import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:sumquiz/models/user_model.dart';

/// IAP Service for handling Play Store purchases
/// Direct Play Store integration for subscription management
class IAPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _proMonthlyId = 'sumquiz_pro_monthly';
  static const String _proYearlyId = 'sumquiz_pro_yearly';
  static const String _proLifetimeId = 'sumquiz_pro_lifetime';
  static const String _examPassId = 'sumquiz_exam_24h'; // NEW: 24-hour pass
  static const String _weekPassId = 'sumquiz_week_pass'; // NEW: 7-day pass

  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final Set<String> _productIds = {
    _proMonthlyId,
    _proYearlyId,
    _proLifetimeId,
    _examPassId, // NEW
    _weekPassId, // NEW
  };

  // Freemium limits
  static const int freeUploadsLifetime = 1;
  static const int freeFoldersMax = 2;
  static const int freeSrsCardsMax = 50;

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

      if (purchaseDetails.productID == _proLifetimeId) {
        // Lifetime: Set expiry far in the future (100 years)
        expiryDate = DateTime.now().add(const Duration(days: 36500));
      } else if (purchaseDetails.productID == _examPassId) {
        // NEW: Exam Pass - 24 hours
        expiryDate = DateTime.now().add(const Duration(hours: 24));
      } else if (purchaseDetails.productID == _weekPassId) {
        // NEW: Week Pass - 7 days
        expiryDate = DateTime.now().add(const Duration(days: 7));
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
      // Note: isPro is a computed getter, so we only update subscriptionExpiry
      await _firestore.collection('users').doc(uid).set({
        'subscriptionExpiry':
            expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
        'isTrial': false, // Paid subscription, not trial
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

      // Make purchase - use consumable for passes, non-consumable for subscriptions
      final purchaseParam = PurchaseParam(productDetails: product);

      if (productId == _examPassId || productId == _weekPassId) {
        // Consumable: can be purchased multiple times
        return await InAppPurchase.instance.buyConsumable(
          purchaseParam: purchaseParam,
        );
      } else {
        // Non-consumable: subscriptions and lifetime
        return await InAppPurchase.instance.buyNonConsumable(
          purchaseParam: purchaseParam,
        );
      }
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

      // Email verification check removed - not fully implemented

      // Get user document and use UserModel to check Pro status
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      // Use UserModel to properly check Pro status
      final userModel = UserModel.fromFirestore(doc);
      return userModel.isPro;
    } catch (e) {
      developer.log('Failed to check Pro access', name: 'IAPService', error: e);
      return false;
    }
  }

  /// Get usage counts for FREE tier users
  Future<Map<String, dynamic>> getFreeTierUsage(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return {};

      final data = doc.data();
      if (data == null) return {};

      return {
        'totalUploads': data['totalUploads'] ?? 0,
        'folderCount': data['folderCount'] ?? 0,
        'srsCardCount': data['srsCardCount'] ?? 0,
      };
    } catch (e) {
      developer.log('Failed to get usage data', name: 'IAPService', error: e);
      return {};
    }
  }

  /// Check if FREE tier user has reached upload limit
  Future<bool> isUploadLimitReached(String uid) async {
    final usage = await getFreeTierUsage(uid);
    final totalUploads = usage['totalUploads'] as int? ?? 0;
    return totalUploads >= freeUploadsLifetime;
  }

  /// Check if FREE tier user has reached folder limit
  Future<bool> isFolderLimitReached(String uid) async {
    final usage = await getFreeTierUsage(uid);
    final folderCount = usage['folderCount'] as int? ?? 0;
    return folderCount >= freeFoldersMax;
  }

  /// Check if FREE tier user has reached SRS card limit
  Future<bool> isSrsCardLimitReached(String uid) async {
    final usage = await getFreeTierUsage(uid);
    final srsCardCount = usage['srsCardCount'] as int? ?? 0;
    return srsCardCount >= freeSrsCardsMax;
  }

  /// Stream Pro status from Firestore
  Stream<bool> isProStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;

      // Use UserModel to properly check Pro status
      final userModel = UserModel.fromFirestore(snapshot);
      return userModel.isPro;
    }).handleError((error) {
      developer.log('Error in isProStream: $error',
          name: 'IAPService', error: error);
      return false;
    });
  }

  /// Stream usage data for FREE tier users
  Stream<Map> usageStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return {};
      final data = snapshot.data() as Map<String, dynamic>;

      return {
        'totalUploads': data['totalUploads'] ?? 0,
        'folderCount': data['folderCount'] ?? 0,
        'srsCardCount': data['srsCardCount'] ?? 0,
      };
    }).handleError((error) {
      developer.log('Error in usageStream: $error',
          name: 'IAPService', error: error);
      return {};
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
