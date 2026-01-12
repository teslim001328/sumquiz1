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
import 'package:sumquiz/services/rate_limiter.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;

import 'package:sumquiz/services/spaced_repetition_service.dart';
import 'package:sumquiz/services/sync_service.dart';

// --- EXCEPTIONS ---
class EnhancedAIServiceException implements Exception {
  final String message;
  EnhancedAIServiceException(this.message);
  @override
  String toString() => message;
}

// --- CONFIG ---
class EnhancedAIConfig {
  static const String primaryModel = 'gemini-1.5-flash';
  static const String fallbackModel = 'gemini-1.5-pro';
  static const String visionModel = 'gemini-1.5-flash';
  static const int maxRetries = 2;
  static const int requestTimeoutSeconds = 120; // Increased for video
  static const int maxInputLength = 30000;
  static const int maxPdfSize = 15 * 1024 * 1024; // 15MB
}

// --- SERVICE ---
class EnhancedAIService {
  final IAPService _iapService;
  late final GenerativeModel _model;
  late final GenerativeModel _fallbackModel;
  late final GenerativeModel _visionModel;

  // Rate limiters for different tiers
  final RateLimiter _freeUserLimiter = RateLimiter(
    maxRequests: 10,
    window: const Duration(minutes: 5),
  );

  final RateLimiter _proUserLimiter = RateLimiter(
    maxRequests: 100,
    window: const Duration(minutes: 5),
  );

  EnhancedAIService({required IAPService iapService})
      : _iapService = iapService {
    final apiKey = dotenv.env['GEMINI_API_KEY']!;

    _model = GenerativeModel(
      model: EnhancedAIConfig.primaryModel,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        maxOutputTokens: 8192,
        responseMimeType: 'application/json',
      ),
    );

    _fallbackModel = GenerativeModel(
      model: EnhancedAIConfig.fallbackModel,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4, // Slightly higher for creativity if primary fails
        maxOutputTokens: 8192,
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

  Future<void> _checkRateLimit() async {
    final isPro = await _iapService.hasProAccess();

    if (isPro) {
      await _proUserLimiter.checkLimit();
    } else {
      await _freeUserLimiter.checkLimit();
    }
  }

  Future<void> _checkUsageLimits(String userId) async {
    final isPro = await _iapService.hasProAccess();

    if (!isPro) {
      final isUploadLimitReached = await _iapService.isUploadLimitReached(userId);
      if (isUploadLimitReached) {
        throw EnhancedAIServiceException(
            'You\'ve reached your weekly upload limit. Upgrade to Pro for unlimited uploads.');
      }

      final isFolderLimitReached = await _iapService.isFolderLimitReached(userId);
      if (isFolderLimitReached) {
        throw EnhancedAIServiceException(
            'You\'ve reached your folder limit. Upgrade to Pro for unlimited folders.');
      }
    }
  }

  Future<String> _generateWithFallback(String prompt) async {
    await _checkRateLimit();

    try {
      return await _generateWithModel(_model, prompt, 'Gemini 1.5 Flash');
    } catch (e) {
      developer.log('Primary model failed, trying fallback',
          name: 'EnhancedAIService', error: e);
      await _checkRateLimit();
      return await _generateWithModel(
          _fallbackModel, prompt, 'Gemini 1.5 Pro');
    }
  }

  Future<String> _generateWithModel(
      GenerativeModel model, String prompt, String modelName) async {
    int attempt = 0;
    while (attempt < EnhancedAIConfig.maxRetries) {
      try {
        final chat = model.startChat();
        final response = await chat.sendMessage(Content.text(prompt)).timeout(
            const Duration(seconds: EnhancedAIConfig.requestTimeoutSeconds));

        final responseText = response.text;
        developer.log('Raw AI Response ($modelName): $responseText',
            name: 'EnhancedAIService');
        if (responseText == null || responseText.isEmpty) {
          throw EnhancedAIServiceException('Model returned an empty response.');
        }

        return responseText.trim();
      } on TimeoutException {
        throw EnhancedAIServiceException(
            'The AI model took too long to respond.');
      } catch (e) {
        developer.log(
            'AI Generation Error ($modelName, Attempt ${attempt + 1})',
            name: 'EnhancedAIService',
            error: e);
        attempt++;
        if (attempt >= EnhancedAIConfig.maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
      }
    }
    throw EnhancedAIServiceException('Generation failed.');
  }

  String _sanitizeInput(String input) {
    input = input.replaceAll(RegExp(r'\n{3,}'), '\n\n').replaceAll(RegExp(r' {2,}'), ' ').trim();

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
    final prompt =
        '''You are a text cleaning and structuring tool. Your task is to take the raw text provided and prepare it for studying.
- You MUST remove all non-instructional content like ads, navigation, and conversational filler.
- You MUST fix formatting and sentence structure and organize the content logically with headers.
- You MUST NOT summarize or alter the core information.
- You MUST return only a single, valid JSON object. Do not explain your actions. Do not use Markdown.

Structure:
{
  "cleanedText": "The cleaned and structured text content..."
}

Raw Text:
$sanitizedText
''';

    final jsonString = await _generateWithFallback(prompt);
    try {
      final data = json.decode(jsonString);
      return data['cleanedText'] ?? jsonString;
    } catch (e) {
      return jsonString;
    }
  }
  
  Future<String> analyzeYouTubeVideo(String videoUrl, {required String userId}) async {
    await _checkUsageLimits(userId);
    await _checkRateLimit();

    final videoContent = Content.data('video/youtube', Uri.parse(videoUrl).data!.contentAsBytes());

    final prompt =
        '''You are an expert academic summarizer. Analyze the provided YouTube video and create a detailed, structured summary of its educational content.

Your task is to:
1.  **Extract Key Information:** Identify all main topics, key concepts, definitions, important arguments, and supporting evidence.
2.  **Filter Non-Essential Content:** You MUST completely ignore and remove advertisements, sponsor messages, personal anecdotes, off-topic discussions, and repetitive conversational filler.
3.  **Structure the Output:** Organize the extracted information into a clean, readable text document. Use clear headings, subheadings, and bullet points to create a logical flow.
4.  **Include Timestamps:** Where relevant, include timestamps (e.g., [01:23]) to reference specific visual or audio cues, especially for demonstrations, charts, or critical statements.
5.  **Maintain Neutrality:** Do not add your own opinions or interpretations. The output should be a faithful representation of the video's instructional content.

Return ONLY the structured text summary. Do not add any commentary or explanation of your actions.''';

    try {
      final response = await _visionModel.generateContent([
        Content.text(prompt),
        videoContent,
      ]).timeout(const Duration(seconds: EnhancedAIConfig.requestTimeoutSeconds));

      if (response.text == null || response.text!.trim().isEmpty) {
        throw EnhancedAIServiceException(
            'Model returned an empty response from video analysis.');
      }
      return response.text!;
    } on TimeoutException {
      throw EnhancedAIServiceException(
          'Video analysis timed out. The video might be too long or complex.');
    } catch (e) {
      developer.log('YouTube Video Analysis Failed', name: 'EnhancedAIService', error: e);
      if (e is EnhancedAIServiceException) rethrow;
      throw EnhancedAIServiceException(
          'Failed to analyze the YouTube video: ${e.toString()}');
    }
  }

  Future<String> extractTextFromImage(Uint8List imageBytes, {required String userId}) async {
    await _checkUsageLimits(userId);
    await _checkRateLimit();

    try {
      final imagePart = DataPart('image/jpeg', imageBytes);
      final promptPart = TextPart(
          'Transcribe all text from this image exactly as it appears. Ignore visuals.');

      final response = await _visionModel.generateContent([
        Content.multi([promptPart, imagePart])
      ]).timeout(
          const Duration(seconds: EnhancedAIConfig.requestTimeoutSeconds));

      if (response.text == null || response.text!.isEmpty) {
        throw EnhancedAIServiceException('No text found in image.');
      }
      return response.text!;
    } catch (e) {
      if (e is EnhancedAIServiceException) rethrow;
      developer.log('Vision API Error', name: 'EnhancedAIService', error: e);
      throw EnhancedAIServiceException(
          'Failed to extract text from image: ${e.toString()}');
    }
  }

  Future<String> _generateSummaryJson(String text) async {
    final sanitizedText = _sanitizeInput(text);

    final model = GenerativeModel(
      model: EnhancedAIConfig.primaryModel,
      apiKey: dotenv.env['GEMINI_API_KEY']!,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'title': Schema.string(),
            'content': Schema.string(),
            'tags': Schema.array(items: Schema.string()),
          },
        ),
      ),
    );

    final prompt = '''Create a comprehensive study guide from this text. Focus on key concepts, definitions, and important facts.

Text: $sanitizedText''';

    try {
      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 60));

      if (response.text == null || response.text!.isEmpty) {
        throw EnhancedAIServiceException('Empty response from AI');
      }

      final data = json.decode(response.text!);

      if (!data.containsKey('title') || !data.containsKey('content')) {
        throw EnhancedAIServiceException('Invalid response structure');
      }

      return response.text!;
    } catch (e) {
      developer.log('Summary generation failed',
          name: 'EnhancedAIService', error: e);

      if (e is EnhancedAIServiceException) rethrow;

      throw EnhancedAIServiceException(
          'Failed to generate summary: ${e.toString()}');
    }
  }

  Future<String> _generateQuizJson(String text) async {
    final sanitizedText = _sanitizeInput(text);
    final prompt =
        '''Create a challenging multiple-choice exam quiz based on the text.
- Determine the number of questions based on the length and depth of the content (aim for comprehensive coverage).
- Questions should mimic real exam questions (application of knowledge, not just keyword matching).
- Focus on high-yield facts, common misconceptions, and critical details.
- Each question must have exactly 4 options.
- The "correctAnswer" must be one of the options.
- The other 3 options (distractors) must be plausible but incorrect (common mistakes).

Return ONLY a single, valid JSON object. Do not use Markdown formatted code blocks (no ```json).
Structure:
{
  "questions": [
    {
      "question": "A diagnostic-style question...?",
      "options": ["Correct Answer", "Plausible Distractor 1", "Plausible Distractor 2", "Plausible Distractor 3"],
      "correctAnswer": "Correct Answer"
    }
  ]
}

Text Source:
$sanitizedText''';
    return _generateWithFallback(prompt);
  }

  Future<String> _generateFlashcardsJson(String text) async {
    final sanitizedText = _sanitizeInput(text);
    final prompt =
        '''Generate high-quality flashcards for Active Recall study based on the text.
- Determine the number of flashcards based on the amount of key information spread throughout the text.
- Focus on the most important facts likely to appear on an exam.
- Front (Question): A specific prompt, term, or concept.
- Back (Answer): The precise definition, explanation, or key fact. Avoid vague answers.
- Cover: Definitions, Dates, Formulas, Key Figures, Cause-Effect relationships.

Return ONLY a single, valid JSON object. Do not use Markdown formatted code blocks (no ```json).
Structure:
{
  "flashcards": [
    {
      "question": "What is the primary function of [Concept]?",
      "answer": "[Precise Explanation]"
    }
  ]
}

Text Source:
$sanitizedText''';
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

    final srsService = SpacedRepetitionService(localDb.getSpacedRepetitionBox());

    int completed = 0;
    final total = requestedOutputs.length;

    try {
      for (String outputType in requestedOutputs) {
        onProgress('Generating ${outputType.capitalize()} (${completed + 1}/$total)...');

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
                  jsonString, userId, title, localDb, folderId, srsService);
              break;
          }

          completed++;
          onProgress('${outputType.capitalize()} complete! ✓');
        } catch (e) {
          developer.log('Failed to generate $outputType',
              name: 'EnhancedAIService', error: e);
          onProgress('${outputType.capitalize()} failed - continuing...');
        }
      }

      if (completed == 0) {
        await localDb.deleteFolder(folderId);
        throw EnhancedAIServiceException('Failed to generate any content');
      }

      onProgress('All done! 🎉');

      SyncService(localDb).syncAllData();

      return folderId;
    } catch (e) {
      onProgress('Error occurred. Cleaning up...');
      await localDb.deleteFolder(folderId);

      if (e is EnhancedAIServiceException) rethrow;
      throw EnhancedAIServiceException(
          'Content generation failed: ${e.toString()}');
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
      throw Exception('No quiz questions generated');
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
      throw Exception('No flashcards generated');
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
