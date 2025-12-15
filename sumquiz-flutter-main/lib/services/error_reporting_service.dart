import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

/// HIGH PRIORITY FIX H8: Crash Reporting / Logging
class ErrorReportingService {
  static final ErrorReportingService _instance =
      ErrorReportingService._internal();
  factory ErrorReportingService() => _instance;
  ErrorReportingService._internal();

  /// Report an error to the backend for crash reporting
  Future<void> reportError(Object error, StackTrace stackTrace,
      {String? context}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      final callable =
          FirebaseFunctions.instance.httpsCallable('logClientError');
      await callable.call({
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
        'context': context,
        'userId': user?.uid,
        'timestamp': DateTime.now().toIso8601String(),
      });

      developer.log('Error reported to backend', name: 'ErrorReportingService');
    } catch (e) {
      // Don't let error reporting errors crash the app
      developer.log('Failed to report error to backend',
          error: e, name: 'ErrorReportingService');
    }
  }

  /// Report a custom error message
  Future<void> reportMessage(String message, {String? context}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      final callable =
          FirebaseFunctions.instance.httpsCallable('logClientError');
      await callable.call({
        'error': message,
        'context': context,
        'userId': user?.uid,
        'timestamp': DateTime.now().toIso8601String(),
      });

      developer.log('Message reported to backend',
          name: 'ErrorReportingService');
    } catch (e) {
      // Don't let error reporting errors crash the app
      developer.log('Failed to report message to backend',
          error: e, name: 'ErrorReportingService');
    }
  }
}
