import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/iap_service.dart';

class SubscriptionProvider with ChangeNotifier {
  final IAPService _iapService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  SubscriptionProvider(this._iapService) {
    _initialize();
  }

  // Subscription state
  bool _isLoading = false;
  bool _isSubscribed = false;
  DateTime? _subscriptionExpiry;
  String? _currentProduct;
  bool _isTrial = false;

  // Getters
  bool get isLoading => _isLoading;
  bool get isSubscribed => _isSubscribed;
  DateTime? get subscriptionExpiry => _subscriptionExpiry;
  String? get currentProduct => _currentProduct;
  bool get isTrial => _isTrial;
  bool get isActive =>
      _isSubscribed &&
      (_subscriptionExpiry == null ||
          _subscriptionExpiry!.isAfter(DateTime.now()));

  // Initialize and listen to user changes
  void _initialize() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _listenToUser(user.uid);
      } else {
        _clearState();
      }
    });
  }

  // Listen to user document changes
  void _listenToUser(String uid) {
    _userSubscription?.cancel();
    _userSubscription =
        _firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _currentUser = UserModel.fromFirestore(snapshot);
        _updateSubscriptionState();
      } else {
        _clearState();
      }
    });
  }

  // Update subscription state from user model
  void _updateSubscriptionState() {
    if (_currentUser == null) {
      _clearState();
      return;
    }

    _isSubscribed = _currentUser!.isPro;
    _subscriptionExpiry = _currentUser!.subscriptionExpiry;
    _currentProduct = _currentUser!.currentProduct;
    _isTrial = _currentUser!.isTrial;

    notifyListeners();
  }

  // Clear subscription state
  void _clearState() {
    _isSubscribed = false;
    _subscriptionExpiry = null;
    _currentProduct = null;
    _isTrial = false;
    _currentUser = null;
    notifyListeners();
  }

  // Purchase a product
  Future<bool> purchaseProduct(String productId) async {
    if (_isLoading) return false;

    _setLoading(true);

    try {
      final success = await _iapService.purchaseProduct(productId);

      if (success) {
        // Wait a bit for the purchase to be processed and reflected in Firestore
        await Future.delayed(const Duration(seconds: 3));

        // Force refresh user data
        await _refreshUserData();
      }

      return success;
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Restore purchases
  Future<void> restorePurchases() async {
    if (_isLoading) return;

    _setLoading(true);

    try {
      await _iapService.restorePurchases();
      await Future.delayed(const Duration(seconds: 2));
      await _refreshUserData();
    } catch (e) {
      debugPrint('Restore error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Refresh user data from Firestore
  Future<void> _refreshUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
        _updateSubscriptionState();
      }
    }
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Check if user can access a Pro feature
  bool canAccessProFeature() {
    return isActive;
  }

  // Check if user is approaching expiration (within 3 days)
  bool isExpiringSoon() {
    if (_subscriptionExpiry == null) return false;

    final now = DateTime.now();
    final difference = _subscriptionExpiry!.difference(now);

    return difference.inDays <= 3 && difference.inDays >= 0;
  }

  // Get formatted expiry date
  String? getFormattedExpiry() {
    if (_subscriptionExpiry == null) return null;

    final now = DateTime.now();
    final difference = _subscriptionExpiry!.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} days';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours';
    } else {
      return 'Less than 1 hour';
    }
  }

  // Dispose resources
  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
