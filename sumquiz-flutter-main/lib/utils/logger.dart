import 'dart:developer' as developer;
import 'package:cloud_functions/cloud_functions.dart';

class Logger {
  static void log(String message) {
    developer.log(message, name: 'sumquiz_app');
  }

  static void error(String message,
      [Object? error, StackTrace? stackTrace, String? context]) {
    developer.log(
      message,
      name: 'sumquiz_app.error',
      error: error,
      stackTrace: stackTrace,
    );

    // HIGH PRIORITY FIX H8: Crash Reporting / Logging
    _reportError(message, error, stackTrace, context);
  }

  static Future<void> _reportError(String message, Object? error,
      StackTrace? stackTrace, String? context) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('logClientError');
      await callable.call({
        'error': message,
        'stackTrace': stackTrace?.toString(),
        'context': context,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Don't let error reporting errors crash the app
      developer.log('Failed to report error to backend', error: e);
    }
  }
}
