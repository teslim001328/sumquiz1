import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_ai/firebase_ai.dart';
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

// --- EXCEPTIONS ---
class EnhancedAIServiceException implements Exception {
  final String message;
  EnhancedAIServiceException(this.message);
  @override
  String toString() => message;
}

// --- CONFIG ---
class EnhancedAIConfig {
  static const String textModel = 'gemini-2.0-flash-exp';
  static const int maxRetries = 2;
  static const int requestTimeoutSeconds = 60;
  static const int maxInputLength = 30000;
}

// --- SERVICE ---
class EnhancedAIService {
  final GenerativeModel _model;

  EnhancedAIService({GenerativeModel? model})
      : _model = model ??
            FirebaseAI.vertexAI().generativeModel(
              model: EnhancedAIConfig.textModel,
              generationConfig: GenerationConfig(
                temperature: 0.3,
                maxOutputTokens: 8192,
                responseMimeType: 'application/json',
              ),
            );

  Future<String> _generateWithRetry(String prompt) async {
    int attempt = 0;
    while (attempt < EnhancedAIConfig.maxRetries) {
      try {
        final chat = _model.startChat();
        final response = await chat.sendMessage(Content.text(prompt)).timeout(
            const Duration(seconds: EnhancedAIConfig.requestTimeoutSeconds));

        final responseText = response.text;
        developer.log('Raw AI Response: $responseText',
            name: 'EnhancedAIService');
        if (responseText == null || responseText.isEmpty) {
          throw EnhancedAIServiceException('Model returned an empty response.');
        }

        final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
        final match = jsonRegex.firstMatch(responseText);
        if (match != null && match.group(1) != null) {
          return match.group(1)!.trim();
        }

        // Fallback: Attempt to extract JSON from raw text (find first '{' and last '}')
        final startIndex = responseText.indexOf('{');
        final endIndex = responseText.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          return responseText.substring(startIndex, endIndex + 1).trim();
        }

        return responseText.trim();
      } on TimeoutException {
        throw EnhancedAIServiceException(
            'The AI model took too long to respond. Please try again.');
      } catch (e) {
        developer.log('AI Generation Error (Attempt ${attempt + 1})',
            name: 'EnhancedAIService', error: e);
        attempt++;
        if (attempt >= EnhancedAIConfig.maxRetries) {
          throw EnhancedAIServiceException(
              'Failed to generate content after several attempts. The AI model may be temporarily unavailable.');
        }
        await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
      }
    }
    throw EnhancedAIServiceException(
        'An unknown error occurred during AI generation.');
  }

  String _sanitizeInput(String input) {
    if (input.length > EnhancedAIConfig.maxInputLength) {
      input = input.substring(0, EnhancedAIConfig.maxInputLength);
    }
    return input.replaceAll(RegExp(r'[\n\r]+'), ' ').trim();
  }

  Future<String> _generateSummaryJson(String text) async {
    final sanitizedText = _sanitizeInput(text);
    final prompt = '''Analyze the text and generate a summary.
Return ONLY a single, valid JSON object. Do not use Markdown formatted code blocks.
Structure: {"title": "A Concise Title", "content": "The summary.", "tags": ["tag1", "tag2"]}

Text: $sanitizedText''';
    return _generateWithRetry(prompt);
  }

  Future<String> _generateQuizJson(String text) async {
    final sanitizedText = _sanitizeInput(text);
    final prompt =
        '''Create a multiple-choice quiz with 5-10 questions from the text.
Each question must have 4 options and one correct answer.
Return ONLY a single, valid JSON object. Do not use Markdown formatted code blocks.
Structure: {"questions": [{"question": "...", "options": ["A", "B", "C", "D"], "correctAnswer": "A"}]}

Text: $sanitizedText''';
    return _generateWithRetry(prompt);
  }

  Future<String> _generateFlashcardsJson(String text) async {
    final sanitizedText = _sanitizeInput(text);
    final prompt = '''Generate 5-15 flashcards from the text.
Each card must have a question and an answer.
Return ONLY a single, valid JSON object. Do not use Markdown formatted code blocks.
Structure: {"flashcards": [{"question": "Term", "answer": "Definition"}]}

Text: $sanitizedText''';
    return _generateWithRetry(prompt);
  }

// ... (existing code)

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
            if (questions.isEmpty)
              throw Exception('The AI failed to generate quiz questions.');
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
            if (flashcards.isEmpty)
              throw Exception('The AI failed to generate flashcards.');
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
      return folderId;
    } catch (e) {
      onProgress('An error occurred. Cleaning up...');
      await localDb.deleteFolder(folderId);
      developer.log('Rolled back folder creation due to error.',
          name: 'EnhancedAIService', error: e);
      throw EnhancedAIServiceException(
          'Failed to create content. The AI may have returned an invalid format. Please try again. Error: ${e.toString()}');
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
