import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sumquiz/models/folder.dart';
import 'package:sumquiz/models/local_flashcard.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/services/local_database_service.dart';
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
  // Updated to Jan 2026 standards
  static const String textModel = 'gemini-2.5-flash'; // Free-tier model
  static const String fallbackModel = 'gemini-2.5-flash'; // Paid, more capable
  static const String visionModel =
      'gemini-2.5-flash'; // Free-tier vision model
  static const int maxRetries = 2;
  static const int requestTimeoutSeconds = 60;
  static const int maxInputLength = 30000;
}

// --- SERVICE ---
class EnhancedAIService {
  static const String _apiKey = 'AIzaSyBmHJxcu_m_yiL_rCJqFuk1J7mFY_PG9RM';
  final GenerativeModel _model;
  final GenerativeModel _fallbackModel;
  final GenerativeModel _visionModel;

  EnhancedAIService({GenerativeModel? model})
      : _model = model ??
            GenerativeModel(
              model: EnhancedAIConfig.textModel,
              apiKey: _apiKey,
              generationConfig: GenerationConfig(
                temperature: 0.3,
                maxOutputTokens: 8192,
                responseMimeType: 'application/json',
              ),
            ),
        _fallbackModel = GenerativeModel(
          model: EnhancedAIConfig.fallbackModel,
          apiKey: _apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.3,
            maxOutputTokens: 8192,
            responseMimeType: 'application/json',
          ),
        ),
        _visionModel = GenerativeModel(
          model: EnhancedAIConfig.visionModel,
          apiKey: _apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.1,
            maxOutputTokens: 2048,
          ),
        );

  Future<String> _generateWithFallback(String prompt) async {
    try {
      return await _generateWithModel(_model, prompt, 'Gemini 1.5 Flash');
    } catch (e) {
      developer.log('Gemini 1.5 Flash failed, falling back to 1.5 Flash',
          name: 'EnhancedAIService', error: e);
      return await _generateWithModel(
          _fallbackModel, prompt, 'Gemini 1.5 Flash');
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

        // Extract JSON from markdown code blocks
        final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
        final match = jsonRegex.firstMatch(responseText);
        if (match != null && match.group(1) != null) {
          return match.group(1)!.trim();
        }

        // Fallback: Extract JSON from raw text (find first '{' and last '}')
        final startIndex = responseText.indexOf('{');
        final endIndex = responseText.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          return responseText.substring(startIndex, endIndex + 1).trim();
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
          rethrow; // Rethrow to let fallback handle it or fail
        }
        await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
      }
    }
    throw EnhancedAIServiceException('Generation failed.');
  }

  String _sanitizeInput(String input) {
    if (input.length > EnhancedAIConfig.maxInputLength) {
      input = input.substring(0, EnhancedAIConfig.maxInputLength);
    }
    return input.replaceAll(RegExp(r'[\n\r]+'), ' ').trim();
  }

  Future<String> refineContent(String rawText) async {
    final sanitizedText = _sanitizeInput(rawText);
    final prompt =
        '''You are an expert study assistant. Your goal is to prepare this raw text for exam studying.
Clean, organize, and structure the text.
- Remove ads, navigation menus, boilerplate, and irrelevant interjections.
- Fix broken sentences or formatting issues.
- Organize the content into clear, logical sections with headers if needed.
- Maintain ALL factual information, data, and key concepts. Do not summarize yet, just clean and structure.
- If the text is already clean, just return it as is.
- Return ONLY a single, valid JSON object. Do not use Markdown formatted code blocks (no ```json).

Structure:
{
  "cleanedText": "The refined and organized text content..."
}

Raw Text:
$sanitizedText''';

    final jsonString = await _generateWithFallback(prompt);
    try {
      final data = json.decode(jsonString);
      return data['cleanedText'] ?? jsonString;
    } catch (e) {
      // If parsing fails, return the raw string (fallback)
      return jsonString;
    }
  }

  Future<String> extractTextFromImage(var imageBytes) async {
    // Note: imageBytes is typically Uint8List
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

  /// Analyzes a YouTube video directly using Gemini's native multimodal capabilities.
  /// Requires a valid [videoUrl].
  Future<String> analyzeYoutubeVideo(String videoUrl) async {
    try {
      final prompt =
          '''Analyze the YouTube video at the following URL: $videoUrl
          
Goal: Provide a comprehensive, detailed transcript-like summary of the video content.
- Include key visual details (diagrams, code snippets, on-screen text) that might be missed in a pure audio transcript.
- Capture the structure and flow of the presentation.
- Do not summarize yet; just extract and describe the content in full detail so it can be processed into a study guide later.
''';

      // We use the primary model as Gemini 2.5 Flash is multimodal.
      return await _generateWithModel(
          _model, prompt, 'Gemini 2.5 Flash (Video)');
    } catch (e) {
      developer.log('Native Video Analysis Failed',
          name: 'EnhancedAIService', error: e);
      // Rethrow so the caller can decide to fallback to transcript
      throw EnhancedAIServiceException(
          'Native video analysis failed: ${e.toString()}');
    }
  }

  Future<String> _generateSummaryJson(String text) async {
    final sanitizedText = _sanitizeInput(text);
    final prompt =
        '''Create a comprehensive "Exam Study Guide" from the provided text.
The summary should be structured as a high-yield cheat sheet for a student preparing for a test.
- Title: A clear, topic-focused title.
- Content: A detailed summary focusing on core concepts, definitions, dates, formulas, and arguments. Use bullet points or numbered lists in the text for readability.
- Tags: 3-5 keywords relevant to the exam topic.

Return ONLY a single, valid JSON object. Do not use Markdown formatted code blocks (no ```json).
Structure:
{
  "title": "Topic Name - Study Guide",
  "content": "The refined study guide content...",
  "tags": ["Concept A", "Concept B", "Subject"]
}

Text to Analyze:
$sanitizedText''';
    return _generateWithFallback(prompt);
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
    final folderId = const Uuid().v4();
    onProgress('Creating a new folder...');
    final folder = Folder(
      id: folderId,
      name: title,
      userId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await localDb.saveFolder(folder);

    // Initialize SRS Service
    final srsService =
        SpacedRepetitionService(localDb.getSpacedRepetitionBox());

    try {
      final generationFutures = <String, Future<String>>{};
      for (String outputType in requestedOutputs) {
        onProgress('Asking AI to generate ${outputType.capitalize()}...');
        switch (outputType) {
          case 'summary':
            generationFutures['summary'] = _generateSummaryJson(text);
            break;
          case 'quiz':
            generationFutures['quiz'] = _generateQuizJson(text);
            break;
          case 'flashcards':
            generationFutures['flashcards'] = _generateFlashcardsJson(text);
            break;
        }
      }

      final generatedJsonStrings = await Future.wait(generationFutures.values);
      final generatedData =
          Map.fromIterables(generationFutures.keys, generatedJsonStrings);

      onProgress('Saving content to your library...');

      for (String outputType in generatedData.keys) {
        final jsonString = generatedData[outputType]!;
        final data = json.decode(jsonString);

        switch (outputType) {
          case 'summary':
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
            break;
          case 'quiz':
            final questions = (data['questions'] as List)
                .map((q) => LocalQuizQuestion(
                      question: q['question'] ?? '',
                      options: List<String>.from(q['options'] ?? []),
                      correctAnswer: q['correctAnswer'] ?? '',
                    ))
                .toList();
            if (questions.isEmpty) {
              throw Exception('The AI failed to generate quiz questions.');
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
            break;
          case 'flashcards':
            final flashcards = (data['flashcards'] as List)
                .map((f) => LocalFlashcard(
                      question: f['question'] ?? '',
                      answer: f['answer'] ?? '',
                    ))
                .toList();
            if (flashcards.isEmpty) {
              throw Exception('The AI failed to generate flashcards.');
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

            // Schedule reviews for each flashcard
            onProgress('Scheduling reviews...');
            for (final flashcard in flashcards) {
              await srsService.scheduleReview(flashcard.id, userId);
            }
            break;
        }
      }

      onProgress('Done!');

      // Trigger background sync to backup new content
      // Don't await this so UI can return immediately
      SyncService(localDb).syncAllData();

      return folderId;
    } catch (e) {
      onProgress('An error occurred. Cleaning up...');
      await localDb.deleteFolder(folderId);
      developer.log('Rolled back folder creation due to error.',
          name: 'EnhancedAIService', error: e);

      if (e is EnhancedAIServiceException) {
        rethrow;
      }

      throw EnhancedAIServiceException(
          'Failed to create content. Error: ${e.toString()}');
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
