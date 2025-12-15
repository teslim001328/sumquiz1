import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class UsageService {
  final String uid;

  UsageService(this.uid);

  /// Check if user can perform an action (server-side validation)
  /// HIGH PRIORITY FIX H5: Move limits logic to Cloud Function
  Future<bool> canPerformAction(String action) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('canPerformAction');
      final result = await callable.call({'action': action});
      return result.data['canPerform'] as bool;
    } catch (e) {
      // Fallback to allowing action if cloud function fails
      print('Error checking usage limit: $e');
      return true;
    }
  }

  /// Record an action (server-side counter)
  /// HIGH PRIORITY FIX H5: Enforce strict counters
  Future<void> recordAction(String action) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('recordAction');
      await callable.call({'action': action});
    } catch (e) {
      print('Error recording action: $e');
      rethrow;
    }
  }
}
