import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sumquiz/models/folder.dart';
import 'package:sumquiz/models/local_flashcard.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;
import 'package:sumquiz/services/spaced_repetition_service.dart';
import 'package:sumquiz/services/sync_service.dart';

// --- RESULT TYPE FOR BETTER ERROR HANDLING ---
sealed class Result<T> {
  const Result();
  factory Result.ok(T value) = Ok._;
  factory Result.error(Exception error) = Error._;
}

final class Ok<T> extends Result<T> {
  const Ok._(this.value);
  final T value;
  @override
  String toString() => 'Result<$T>.ok($value)';
}

final class Error<T> extends Result<T> {
  const Error._(this.error);
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
      code == 'NETWORK_ERROR' ||
      originalError is TimeoutException;
}

// --- CONFIG ---
class EnhancedAIConfig {
  // Updated models as of January 2026
  static const String primaryModel = 'gemini-2.5-flash';
  static const String fallbackModel = 'gemini-1.5-flash';
  static const String visionModel = 'gemini-2.5-flash';
  
  // Retry configuration with exponential backoff
  static const int maxRetries = 5;
  static const int initialRetryDelayMs = 1000;
  static const int maxRetryDelayMs = 60000;
  static const int requestTimeoutSeconds = 120;
  
  // Input/output limits
  static const int maxInputLength = 30000;
  static const int maxPdfSize = 15 * 1024 * 1024; // 15MB
  static const int maxOutputTokens = 8192;
  
  // Model parameters
  static const double defaultTemperature = 0.3;
  static const double fallbackTemperature = 0.4;
}

// --- SERVICE ---
class EnhancedAIService {
  final IAPService _iapService;
  late final GenerativeModel _model;
  late final GenerativeModel _fallbackModel;
  late final GenerativeModel _visionModel;

  EnhancedAIService({required IAPService iapService})
      : _iapService = iapService {
    final apiKey = dotenv.env['API_KEY']!;

    _model = GenerativeModel(
      model: EnhancedAIConfig.primaryModel,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: EnhancedAIConfig.defaultTemperature,
        maxOutputTokens: EnhancedAIConfig.maxOutputTokens,
        responseMimeType: 'application/json',
      ),
    );

    _fallbackModel = GenerativeModel(
      model: EnhancedAIConfig.fallbackModel,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: EnhancedAIConfig.fallbackTemperature,
        maxOutputTokens: EnhancedAIConfig.maxOutputTokens,
        responseMimeType: 'application/json',
      ),
    );

    _visionModel = GenerativeModel(
      model: EnhancedAIConfig.visionModel,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 4096,
      ),
    );
  }

  Future<void> _checkUsageLimits(String userId) async {
    final isPro = await _iapService.hasProAccess();

    if (!isPro) {
      final isUploadLimitReached =
          await _iapService.isUploadLimitReached(userId);
      if (isUploadLimitReached) {
        throw EnhancedAIServiceException(
          'You\'ve reached your weekly upload limit. Upgrade to Pro for unlimited uploads.',
          code: 'UPLOAD_LIMIT_REACHED',
        );
      }

      final isFolderLimitReached =
          await _iapService.isFolderLimitReached(userId);
      if (isFolderLimitReached) {
        throw EnhancedAIServiceException(
          'You\'ve reached your folder limit. Upgrade to Pro for unlimited folders.',
          code: 'FOLDER_LIMIT_REACHED',
        );
      }
    }
  }

  /// Enhanced retry mechanism with exponential backoff and jitter
  Future<String> _generateWithFallback(String prompt) async {
    try {
      return await _generateWithModel(
        _model,
        prompt,
        EnhancedAIConfig.primaryModel,
      );
    } catch (e) {
      developer.log(
        'Primary model (${EnhancedAIConfig.primaryModel}) failed, trying fallback',
        name: 'EnhancedAIService',
        error: e,
      );
      
      try {
        return await _generateWithModel(
          _fallbackModel,
          prompt,
          EnhancedAIConfig.fallbackModel,
        );
      } catch (fallbackError) {
        developer.log(
          'Fallback model (${EnhancedAIConfig.fallbackModel}) also failed',
          name: 'EnhancedAIService',
          error: fallbackError,
        );
        
        throw EnhancedAIServiceException(
          'AI service temporarily unavailable. Please try again in a moment.',
          code: 'SERVICE_UNAVAILABLE',
          originalError: fallbackError,
        );
      }
    }
  }

  /// Generate with exponential backoff and jitter for rate limiting
  Future<String> _generateWithModel(
    GenerativeModel model,
    String prompt,
    String modelName,
  ) async {
    int attempt = 0;
    
    while (attempt < EnhancedAIConfig.maxRetries) {
      try {
        final chat = model.startChat();
        final response = await chat
            .sendMessage(Content.text(prompt))
            .timeout(Duration(seconds: EnhancedAIConfig.requestTimeoutSeconds));

        final responseText = response.text;
        developer.log(
          'AI Response ($modelName, attempt ${attempt + 1}): ${responseText?.substring(0, min(100, responseText.length))}...',
          name: 'EnhancedAIService',
        );

        if (responseText == null || responseText.isEmpty) {
          throw EnhancedAIServiceException(
            'Model returned an empty response.',
            code: 'EMPTY_RESPONSE',
          );
        }

        return responseText.trim();
      } on TimeoutException catch (e) {
        throw EnhancedAIServiceException(
          'Request timed out after ${EnhancedAIConfig.requestTimeoutSeconds} seconds.',
          code: 'TIMEOUT',
          originalError: e,
        );
      } catch (e) {
        attempt++;
        
        // Check if it's a rate limit error
        final isRateLimited = e.toString().contains('RESOURCE_EXHAUSTED') ||
            e.toString().contains('429') ||
            e.toString().contains('rate limit');
        
        developer.log(
          'AI Generation Error ($modelName, Attempt $attempt/${EnhancedAIConfig.maxRetries})',
          name: 'EnhancedAIService',
          error: e,
        );

        if (attempt >= EnhancedAIConfig.maxRetries) {
          if (isRateLimited) {
            throw EnhancedAIServiceException(
              'Rate limit exceeded. Please try again in a few moments.',
              code: 'RESOURCE_EXHAUSTED',
              originalError: e,
            );
          }
          rethrow;
        }

        // Exponential backoff with jitter
        final baseDelay = EnhancedAIConfig.initialRetryDelayMs * pow(2, attempt - 1);
        final jitter = Random().nextInt(1000);
        final delay = min(
          baseDelay.toInt() + jitter,
          EnhancedAIConfig.maxRetryDelayMs,
        );
        
        developer.log(
          'Retrying in ${delay}ms...',
          name: 'EnhancedAIService',
        );
        
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    
    throw EnhancedAIServiceException(
      'Generation failed after ${EnhancedAIConfig.maxRetries} attempts.',
      code: 'MAX_RETRIES_EXCEEDED',
    );
  }

  String _sanitizeInput(String input) {
    input = input
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();

    if (input.length <= EnhancedAIConfig.maxInputLength) {
      return input;
    }

    final maxLength = EnhancedAIConfig.maxInputLength;
    final sentenceEndings = ['. ', '! ', '? ', '.\n', '!\n', '?\n'];
    int bestCutoff = -1;

    for (final ending in sentenceEndings) {
      final lastOccurrence = input.lastIndexOf(ending, maxLength);
      if (lastOccurrence > bestCutoff) {
        bestCutoff = lastOccurrence + ending.length;
      }
    }

    if (bestCutoff > maxLength * 0.8) {
      return input.substring(0, bestCutoff).trim();
    }

    final lastSpace = input.lastIndexOf(' ', maxLength);
    if (lastSpace > maxLength * 0.9) {
      return '${input.substring(0, lastSpace).trim()}...';
    }

    return '${input.substring(0, maxLength - 3).trim()}...';
  }

  Future<String> refineContent(String rawText) async {
    final sanitizedText = _sanitizeInput(rawText);
    final prompt = '''You are an expert content extractor preparing raw text for exam studying.

CRITICAL: Your task is to EXTRACT and CLEAN the content, NOT to summarize or condense it.

WHAT TO DO:
1. REMOVE completely (discard these sections):
   - Advertisements and promotional content
   - Navigation menus, headers, footers
   - "Like and subscribe" calls to action
   - Sponsor messages
   - Unrelated tangents or personal stories
   - Boilerplate text (copyright notices, disclaimers)
   - Repetitive filler phrases

2. FIX and CLEAN:
   - Broken sentences or formatting issues
   - Merge fragmented thoughts into complete sentences
   - Fix obvious typos or OCR errors
   - Remove excessive whitespace or line breaks

3. ORGANIZE:
   - Structure content into logical sections with clear headers
   - Group related concepts together
   - Use bullet points or numbered lists where appropriate for clarity

4. PRESERVE (keep everything):
   - ALL factual information, data points, and statistics
   - ALL key concepts, definitions, and explanations
   - ALL examples, case studies, and practice problems
   - ALL formulas, equations, code snippets, or technical details
   - ALL step-by-step procedures or processes
   - The instructor's exact wording for important concepts

REMEMBER: You are EXTRACTING educational content, not creating a summary.
The goal is clean, organized, study-ready content with ALL the educational value intact.

Return ONLY valid JSON (no markdown code blocks):
{
  "cleanedText": "The extracted, cleaned, and organized content..."
}

Raw Text:
$sanitizedText''';

    String jsonString = '';
    try {
      jsonString = await _generateWithFallback(prompt);
      final data = json.decode(jsonString);
      return data['cleanedText'] ?? jsonString;
    } catch (e) {
      developer.log(
        'Content refinement failed, returning original',
        name: 'EnhancedAIService',
        error: e,
      );
      return jsonString;
    }
  }

  /// Enhanced YouTube video analysis with better error handling
  Future<Result<String>> analyzeYouTubeVideo(
    String videoUrl, {
    required String userId,
  }) async {
    try {
      await _checkUsageLimits(userId);

      final prompt = '''Analyze this YouTube video: $videoUrl

CRITICAL INSTRUCTIONS:
1. WATCH the video - analyze both visual and audio content
2. EXTRACT all instructional content (do NOT summarize)
3. Capture EVERYTHING the instructor teaches:
   - All concepts, definitions, explanations (word-for-word when important)
   - Visual content (slides, diagrams, demonstrations)
   - Examples, case studies, practice problems
   - Formulas, equations, code, technical details
   - Step-by-step procedures
   - Key timestamps [MM:SS]

EXCLUDE:
- Intros, outros, promotions
- Personal stories unrelated to topic
- Jokes, tangents
- Calls to action (like, subscribe)
- Sponsor messages
- Navigation instructions ("in the next video...")
- Repetitive filler phrases

OUTPUT FORMAT:
Clean, organized text with:
- All factual information preserved
- Organized by topic/section
- Visual descriptions where relevant
- Technical accuracy maintained
- Timestamps for key moments

REMEMBER: EXTRACT for study purposes, not summarize.''';

      final response = await _visionModel
          .generateContent([Content.text(prompt)])
          .timeout(Duration(seconds: EnhancedAIConfig.requestTimeoutSeconds));

      if (response.text == null || response.text!.trim().isEmpty) {
        return Result.error(
          EnhancedAIServiceException(
            'Video analysis returned empty response.',
            code: 'EMPTY_RESPONSE',
          ),
        );
      }

      return Result.ok(response.text!);
    } on TimeoutException catch (e) {
      return Result.error(
        EnhancedAIServiceException(
          'Video analysis timed out. Video might be too long.',
          code: 'TIMEOUT',
          originalError: e,
        ),
      );
    } on EnhancedAIServiceException catch (e) {
      return Result.error(e);
    } catch (e) {
      developer.log(
        'YouTube Video Analysis Failed',
        name: 'EnhancedAIService',
        error: e,
      );
      return Result.error(
        EnhancedAIServiceException(
          'Failed to analyze YouTube video.',
          code: 'ANALYSIS_FAILED',
          originalError: e,
        ),
      );
    }
  }

  Future<String> extractTextFromImage(
    Uint8List imageBytes, {
    required String userId,
  }) async {
    await _checkUsageLimits(userId);

    try {
      final imagePart = DataPart('image/jpeg', imageBytes);
      final promptPart = TextPart(
        'Transcribe all text from this image exactly as it appears. '
        'Include all text content, maintaining original formatting where possible. '
        'Ignore non-text visual elements.',
      );

      final response = await _visionModel
          .generateContent([
            Content.multi([promptPart, imagePart])
          ])
          .timeout(Duration(seconds: EnhancedAIConfig.requestTimeoutSeconds));

      if (response.text == null || response.text!.isEmpty) {
        throw EnhancedAIServiceException(
          'No text found in image.',
          code: 'NO_TEXT_FOUND',
        );
      }
      return response.text!;
    } on EnhancedAIServiceException {
      rethrow;
    } catch (e) {
      developer.log('Vision API Error', name: 'EnhancedAIService', error: e);
      throw EnhancedAIServiceException(
        'Failed to extract text from image.',
        code: 'EXTRACTION_FAILED',
        originalError: e,
      );
    }
  }

  /// Generate summary with JSON schema for structured output
  Future<String> _generateSummaryJson(String text) async {
    final sanitizedText = _sanitizeInput(text);

    // Using JSON Schema for structured output (Nov 2025 feature)
    final model = GenerativeModel(
      model: EnhancedAIConfig.primaryModel,
      apiKey: dotenv.env['API_KEY']!,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'title': Schema.string(
              description: 'Clear, topic-focused title',
            ),
            'content': Schema.string(
              description: 'Detailed study guide optimized for exam prep',
            ),
            'tags': Schema.array(
              items: Schema.string(),
              description: '3-5 relevant keywords',
            ),
          },
          requiredProperties: ['title', 'content', 'tags'],
        ),
      ),
    );

    final prompt = '''Create a comprehensive EXAM-FOCUSED study guide from this text.

Your task:
1. **Title**: Create a clear, topic-focused title
2. **Content**: Write a detailed study guide optimized for exam preparation:
   - Start with key concepts and definitions
   - Include all important facts, dates, formulas, technical details
   - Highlight common exam topics
   - Use clear headings and bullet points
   - Include examples illustrating key concepts
   - Add memory aids or mnemonics
   - Organize by topic/subtopic
3. **Tags**: Generate 3-5 relevant keywords

FOCUS: EXAM PREPARATION
Prioritize:
- Information likely to appear on tests
- Definitions and terminology
- Key facts and figures
- Cause-effect relationships
- Processes and procedures
- Common misconceptions

Text: $sanitizedText''';

    try {
      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 60));

      if (response.text == null || response.text!.isEmpty) {
        throw EnhancedAIServiceException(
          'Empty response from AI',
          code: 'EMPTY_RESPONSE',
        );
      }

      final data = json.decode(response.text!);
      if (!data.containsKey('title') || !data.containsKey('content')) {
        throw EnhancedAIServiceException(
          'Invalid response structure',
          code: 'INVALID_STRUCTURE',
        );
      }

      return response.text!;
    } catch (e) {
      developer.log(
        'Summary generation failed',
        name: 'EnhancedAIService',
        error: e,
      );

      if (e is EnhancedAIServiceException) rethrow;
      throw EnhancedAIServiceException(
        'Failed to generate summary.',
        code: 'GENERATION_FAILED',
        originalError: e,
      );
    }
  }

  Future<String> _generateQuizJson(String text) async {
    final sanitizedText = _sanitizeInput(text);
    
    final prompt = '''Create a challenging multiple-choice exam quiz.

Requirements:
- Determine question count based on content depth (comprehensive coverage)
- Questions should mimic real exam questions (application, not just recall)
- Focus on high-yield facts, misconceptions, critical details
- Exactly 4 options per question
- correctAnswer must be one of the options
- 3 plausible but incorrect distractors (common mistakes)

Return ONLY valid JSON (no markdown):
{
  "questions": [
    {
      "question": "Diagnostic-style question...?",
      "options": ["Correct Answer", "Distractor 1", "Distractor 2", "Distractor 3"],
      "correctAnswer": "Correct Answer"
    }
  ]
}

Text: $sanitizedText''';
    
    return _generateWithFallback(prompt);
  }

  Future<String> _generateFlashcardsJson(String text) async {
    final sanitizedText = _sanitizeInput(text);
    
    final prompt = '''Generate high-quality flashcards for Active Recall study.

Requirements:
- Determine count based on key information throughout text
- Focus on exam-likely facts
- Front (Question): Specific prompt, term, or concept
- Back (Answer): Precise definition, explanation, or key fact (no vague answers)
- Cover: Definitions, Dates, Formulas, Key Figures, Cause-Effect relationships

Return ONLY valid JSON (no markdown):
{
  "flashcards": [
    {
      "question": "What is the primary function of [Concept]?",
      "answer": "[Precise Explanation]"
    }
  ]
}

Text: $sanitizedText''';
    
    return _generateWithFallback(prompt);
  }

  Future<String> generateAndStoreOutputs({
    required String text,
    required String title,
    required List<String> requestedOutputs,
    required String userId,
    required LocalDatabaseService localDb,
    required void Function(String message) onProgress,
  }) async {
    onProgress('Creating folder...');
    final folderId = const Uuid().v4();
    final folder = Folder(
      id: folderId,
      name: title,
      userId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await localDb.saveFolder(folder);

    final srsService =
        SpacedRepetitionService(localDb.getSpacedRepetitionBox());

    int completed = 0;
    final total = requestedOutputs.length;
    final failures = <String>[];

    try {
      for (String outputType in requestedOutputs) {
        onProgress(
          'Generating ${outputType.capitalize()} (${completed + 1}/$total)...',
        );

        try {
          switch (outputType) {
            case 'summary':
              final jsonString = await _generateSummaryJson(text);
              onProgress('Saving summary...');
              await _saveSummary(jsonString, userId, title, localDb, folderId);
              break;

            case 'quiz':
              final jsonString = await _generateQuizJson(text);
              onProgress('Saving quiz...');
              await _saveQuiz(jsonString, userId, title, localDb, folderId);
              break;

            case 'flashcards':
              final jsonString = await _generateFlashcardsJson(text);
              onProgress('Saving flashcards...');
              await _saveFlashcards(
                jsonString,
                userId,
                title,
                localDb,
                folderId,
                srsService,
              );
              break;
          }

          completed++;
          onProgress('${outputType.capitalize()} complete! ✓');
        } on EnhancedAIServiceException catch (e) {
          developer.log(
            'Failed to generate $outputType: ${e.message}',
            name: 'EnhancedAIService',
            error: e,
          );
          failures.add(outputType);
          onProgress('${outputType.capitalize()} failed - continuing...');
        } catch (e) {
          developer.log(
            'Unexpected error generating $outputType',
            name: 'EnhancedAIService',
            error: e,
          );
          failures.add(outputType);
          onProgress('${outputType.capitalize()} failed - continuing...');
        }
      }

      if (completed == 0) {
        await localDb.deleteFolder(folderId);
        throw EnhancedAIServiceException(
          'Failed to generate any content. Please try again.',
          code: 'ALL_GENERATION_FAILED',
        );
      }

      if (failures.isNotEmpty) {
        onProgress(
          'Done! ${failures.length} item(s) failed: ${failures.join(", ")}',
        );
      } else {
        onProgress('All done! 🎉');
      }

      // Trigger sync in background
      SyncService(localDb).syncAllData();

      return folderId;
    } catch (e) {
      onProgress('Error occurred. Cleaning up...');
      await localDb.deleteFolder(folderId);

      if (e is EnhancedAIServiceException) rethrow;
      throw EnhancedAIServiceException(
        'Content generation failed.',
        code: 'GENERATION_FAILED',
        originalError: e,
      );
    }
  }

  Future<void> _saveSummary(
    String jsonString,
    String userId,
    String title,
    LocalDatabaseService localDb,
    String folderId,
  ) async {
    final data = json.decode(jsonString);
    final summary = LocalSummary(
      id: const Uuid().v4(),
      userId: userId,
      title: data['title'] ?? title,
      content: data['content'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      timestamp: DateTime.now(),
      isSynced: false,
    );
    await localDb.saveSummary(summary, folderId);
  }

  Future<void> _saveQuiz(
    String jsonString,
    String userId,
    String title,
    LocalDatabaseService localDb,
    String folderId,
  ) async {
    final data = json.decode(jsonString);
    final questions = (data['questions'] as List)
        .map((q) => LocalQuizQuestion(
              question: q['question'] ?? '',
              options: List<String>.from(q['options'] ?? []),
              correctAnswer: q['correctAnswer'] ?? '',
            ))
        .toList();

    if (questions.isEmpty) {
      throw EnhancedAIServiceException(
        'No quiz questions generated',
        code: 'EMPTY_QUIZ',
      );
    }

    final quiz = LocalQuiz(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      questions: questions,
      timestamp: DateTime.now(),
      scores: [],
      isSynced: false,
    );
    await localDb.saveQuiz(quiz, folderId);
  }

  Future<void> _saveFlashcards(
    String jsonString,
    String userId,
    String title,
    LocalDatabaseService localDb,
    String folderId,
    SpacedRepetitionService srsService,
  ) async {
    final data = json.decode(jsonString);
    final flashcards = (data['flashcards'] as List)
        .map((f) => LocalFlashcard(
              question: f['question'] ?? '',
              answer: f['answer'] ?? '',
            ))
        .toList();

    if (flashcards.isEmpty) {
      throw EnhancedAIServiceException(
        'No flashcards generated',
        code: 'EMPTY_FLASHCARDS',
      );
    }

    final flashcardSet = LocalFlashcardSet(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      flashcards: flashcards,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    await localDb.saveFlashcardSet(flashcardSet, folderId);

    for (final flashcard in flashcards) {
      await srsService.scheduleReview(flashcard.id, userId);
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
