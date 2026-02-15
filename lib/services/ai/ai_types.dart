import 'dart:async';

// --- RESULT TYPE FOR BETTER ERROR HANDLING ---
sealed class Result<T> {
  const Result();
  factory Result.ok(T value) = Ok._;
  factory Result.error(Exception error) = ResultError._;
}

final class Ok<T> extends Result<T> {
  const Ok._(this.value);
  final T value;
  @override
  String toString() => 'Result<$T>.ok($value)';
}

final class ResultError<T> extends Result<T> {
  const ResultError._(this.error);
  final Exception error;
  @override
  String toString() => 'Result<$T>.error($error)';
}

// --- EXCEPTIONS ---
class EnhancedAIServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  EnhancedAIServiceException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => code != null ? '[$code] $message' : message;

  bool get isRateLimitError =>
      code == 'RESOURCE_EXHAUSTED' ||
      code == '429' ||
      message.contains('rate limit') ||
      message.contains('quota');

  bool get isNetworkError =>
      code == 'NETWORK_ERROR' || originalError is TimeoutException;
}
