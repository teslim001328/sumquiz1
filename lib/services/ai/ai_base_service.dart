import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;
import 'ai_config.dart';

// --- EXCEPTIONS ---
class AIServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AIServiceException(
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

abstract class AIBaseService {
  GenerativeModel? _model;
  GenerativeModel? _proModel;
  GenerativeModel? _fallbackModel;
  GenerativeModel? _visionModel;

  bool _initialized = false;
  String? _initializationError;

  AIBaseService() {
    _initializeModelsAsync();
  }

  Future<void> _initializeModelsAsync() async {
    try {
      // API Key hardcoded for production/GitHub builds as requested by user
      const String hardcodedApiKey = 'AIzaSyCHKJA1xvUbGsPGL6CKiw5tlILQWYwb540';
      final apiKey = dotenv.env['API_KEY'] ?? hardcodedApiKey;
      
      if (apiKey.isEmpty) {
        _initializationError = 'API key is not configured.';
        return;
      }

      _model = GenerativeModel(
        model: AIConfig.primaryModel,
        apiKey: apiKey,
        generationConfig: AIConfig.defaultGenerationConfig,
      );

      _proModel = GenerativeModel(
        model: AIConfig.proModel,
        apiKey: apiKey,
        generationConfig: AIConfig.proGenerationConfig,
      );

      _fallbackModel = GenerativeModel(
        model: AIConfig.fallbackModel,
        apiKey: apiKey,
        generationConfig: AIConfig.defaultGenerationConfig,
      );

      _visionModel = GenerativeModel(
        model: AIConfig.visionModel,
        apiKey: apiKey,
        generationConfig: AIConfig.defaultGenerationConfig,
      );

      _initialized = true;
    } catch (e) {
      _initializationError = 'Failed to initialize AI models: $e';
    }
  }

  Future<bool> ensureInitialized([int timeoutSeconds = 15]) async {
    if (_initialized) return true;
    
    final stopwatch = Stopwatch()..start();
    while (!_initialized && stopwatch.elapsed.inSeconds < timeoutSeconds) {
      if (_initializationError != null) return false;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _initialized;
  }

  bool _isValidApiKeyFormat(String apiKey) {
    // Google API keys typically start with 'AIza' and have a specific format
    final RegExp googleApiKeyRegex = RegExp(r'^AIza[\w-]{30,}$');
    return googleApiKeyRegex.hasMatch(apiKey);
  }

  Future<bool> isServiceHealthy() async {
    try {
      if (!await ensureInitialized(10)) return false;
      // Simple health check message with more aggressive timeout
      final response = await _model!
          .generateContent([Content.text('Say "ok"')])
          .timeout(const Duration(seconds: 5));
      
      final healthy = response.text != null && response.text!.toLowerCase().contains('ok');
      if (!healthy) {
        developer.log('AI Health Check failed: Unexpected response', name: 'AIBaseService');
      }
      return healthy;
    } catch (e) {
      developer.log('API health check failed: $e', name: 'AIBaseService');
      return false;
    }
  }

  String _sanitizeInput(String input) {
    input = input
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();

    if (input.length <= AIConfig.maxInputLength) return input;

    final maxLength = AIConfig.maxInputLength;
    final sentenceEndings = ['. ', '! ', '? ', '.\n', '!\n', '?\n'];
    int bestCutoff = -1;

    for (final ending in sentenceEndings) {
      final lastOccurrence = input.lastIndexOf(ending, maxLength);
      if (lastOccurrence > bestCutoff) {
        bestCutoff = lastOccurrence + ending.length;
      }
    }

    if (bestCutoff > maxLength * 0.8) return input.substring(0, bestCutoff).trim();
    final lastSpace = input.lastIndexOf(' ', maxLength);
    if (lastSpace > maxLength * 0.9) return '${input.substring(0, lastSpace).trim()}...';
    return '${input.substring(0, maxLength - 3).trim()}...';
  }

  GenerativeModel get model => _model!;
  GenerativeModel get proModel => _proModel!;
  GenerativeModel get fallbackModel => _fallbackModel!;
  GenerativeModel get visionModel => _visionModel!;

  Future<String> generateWithRetry(String prompt, {GenerativeModel? customModel, GenerationConfig? generationConfig}) async {
    return generateMultimodal([TextPart(prompt)], customModel: customModel, generationConfig: generationConfig);
  }

  Future<String> generateMultimodal(List<Part> parts, {GenerativeModel? customModel, GenerationConfig? generationConfig}) async {
    if (!await ensureInitialized()) {
      throw AIServiceException('AI Service not ready: $_initializationError', code: 'SERVICE_NOT_READY');
    }

    // Sanitize any TextPart in the parts
    final sanitizedParts = parts.map((part) {
      if (part is TextPart) {
        return TextPart(_sanitizeInput(part.text));
      }
      return part;
    }).toList();

    var targetModel = customModel ?? _model;
    if (targetModel == null) throw AIServiceException('Model not available', code: 'MODEL_NOT_AVAILABLE');

    // If custom config is provided, we need to re-wrap the model with it
    // Note: GenerativeModel is immutable, but we can use provide custom config per request in newer SDKs
    // but for compatibility we check if we can pass it to generateContent
    
    int attempt = 0;
    while (attempt < AIConfig.maxRetries) {
      try {
        final response = await targetModel
            .generateContent(
              [Content.multi(sanitizedParts)],
              generationConfig: generationConfig, // Supported in newer versions of the SDK
            )
            .timeout(const Duration(seconds: AIConfig.requestTimeoutSeconds));

        final text = response.text;
        if (text == null || text.isEmpty) {
          throw AIServiceException('Empty response from AI', code: 'EMPTY_RESPONSE');
        }
        return text.trim();
      } catch (e) {
        attempt++;
        if (attempt >= AIConfig.maxRetries) rethrow;

        final baseDelay = AIConfig.initialRetryDelayMs * pow(2, attempt - 1);
        final jitter = Random().nextInt(1000);
        final delay = min(
          baseDelay.toInt() + jitter,
          AIConfig.maxRetryDelayMs,
        ).toInt();
        
        developer.log('AI Retry attempt $attempt in ${delay}ms', name: 'AIBaseService', error: e);
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    throw AIServiceException('Max retries exceeded', code: 'MAX_RETRIES');
  }

  String extractJson(String response) {
    String cleaned = response.trim();
    final jsonBlockRegex = RegExp(r'```(?:json|JSON)?\s*\n?([\s\S]*?)\n?```', multiLine: true);
    final match = jsonBlockRegex.firstMatch(cleaned);
    
    if (match != null && match.group(1) != null) {
      cleaned = match.group(1)!.trim();
    }

    if (!cleaned.startsWith('{') && !cleaned.startsWith('[')) {
      final start = cleaned.indexOf(RegExp(r'[\{\[]'));
      if (start >= 0) {
        final end = cleaned.lastIndexOf(cleaned[start] == '{' ? '}' : ']');
        if (end > start) {
          cleaned = cleaned.substring(start, end + 1);
        }
      }
    }
    return cleaned;
  }
}
