import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:sumquiz/models/summary_model.dart' as model_summary;

import '../models/flashcard.dart';
import '../models/quiz_model.dart';
import '../models/quiz_question.dart';
import '../models/local_summary.dart';
import '../models/local_quiz.dart';
import '../models/local_quiz_question.dart';
import '../models/local_flashcard_set.dart';
import '../models/local_flashcard.dart';
import '../models/folder.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;

class AIServiceException implements Exception {
  final String message;
  AIServiceException(this.message);
  @override
  String toString() => message;
}

class AIConfig {
  static const String textModel = 'gemini-2.5-flash';
  static const String visionModel = 'gemini-2.5-pro';
  static const int maxRetries = 3;
  static const int requestTimeout = 45;
  static const int maxInputLength = 15000;
  static const int maxPdfSize = 15 * 1024 * 1024;
}

class AIService {
  final GenerativeModel _textModel;
  final GenerativeModel _visionModel;
  final ImagePicker _imagePicker;
  final IAPService? _iapService;

  AIService({
    GenerativeModel? textModel,
    GenerativeModel? visionModel,
    ImagePicker? imagePicker,
    IAPService? iapService,
  })  : _textModel = textModel ?? 
          FirebaseAI.vertexAI().generativeModel(
            model: AIConfig.textModel,
            generationConfig: GenerationConfig(
              temperature: 0.7,
              topK: 40,
              topP: 0.95,
              maxOutputTokens: 4096,
            ),
          ),
        _visionModel = visionModel ??
          FirebaseAI.vertexAI().generativeModel(
            model: AIConfig.visionModel,
            generationConfig: GenerationConfig(
              temperature: 0.7,
              topK: 40,
              topP: 0.95,
              maxOutputTokens: 4096,
            ),
          ),
        _imagePicker = imagePicker ?? ImagePicker(),
        _iapService = iapService;

  Future<T> _retryWithBackoff<T>(Future<T> Function() operation,
      {int maxRetries = AIConfig.maxRetries}) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        return await operation();
      } on TimeoutException {
        throw AIServiceException('Request timed out. Please try again.');
      } catch (e) {
        developer.log('AI Error (Attempt ${attempt + 1})', name: 'EnhancedAIService', error: e);
        attempt++;
        if (attempt >= maxRetries) rethrow;
        final delay = Duration(seconds: pow(2, attempt).toInt());
        developer.log('Retry attempt $attempt after $delay',
            name: 'my_app.ai_service');
        await Future.delayed(delay);
      }
    }
    throw Exception('Max retries exceeded');
  }

  String _cleanJsonResponse(String text) {
    text = text
        .replaceAll(RegExp(r"```json\s*"), "")
        .replaceAll(RegExp(r"```\s*$"), "");
    text = text.replaceAll("```", "").trim();
    try {
      json.decode(text);
      return text;
    } catch (e) {
      throw FormatException('Response is not valid JSON: $text');
    }
  }

  String _sanitizeInput(String input) {
    return input
        .replaceAll(RegExp(r'[\n\r]+'), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  Future<String> getSuggestion(String text) async {
    if (text.trim().isEmpty) {
      throw AIServiceException('Cannot provide suggestions for empty text.');
    }
    if (text.length > AIConfig.maxInputLength) {
      throw AIServiceException(
          'Text too long. Maximum length is ${AIConfig.maxInputLength} characters.');
    }

    final prompt =
        'Provide a suggestion to improve the following text: ${_sanitizeInput(text)}';

    try {
      final response = await _retryWithBackoff(() => _textModel
          .generateContent([Content.text(prompt)]).timeout(
              const Duration(seconds: AIConfig.requestTimeout)));
      if (response.text == null || response.text!.isEmpty) {
        throw AIServiceException('Model returned empty response.');
      }
      return response.text!;
    } on TimeoutException {
      throw AIServiceException('Request timed out. Please try again.');
    } catch (e) {
      developer.log('Error getting suggestion',
          name: 'my_app.ai_service', error: e);
      throw AIServiceException('Failed to get suggestion: ${e.toString()}');
    }
  }

  Future<String> generateSummary(String text,
      {Uint8List? pdfBytes, String? userId}) async {
    // Check usage limits for FREE tier users
    if (_iapService != null && userId != null) {
      final isPro = await _iapService.hasProAccess();
      if (!isPro) {
        final isLimitReached = await _iapService.isUploadLimitReached(userId);
        if (isLimitReached) {
          throw AIServiceException(
              'Weekly upload limit reached. Upgrade to Pro for unlimited access.');
        }
      }
    }

    if (pdfBytes != null) {
      if (pdfBytes.length > AIConfig.maxPdfSize) {
        throw AIServiceException('PDF file too large. Maximum size is 15MB.');
      }
      try {
        final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
        text = PdfTextExtractor(document).extractText();
        document.dispose();
      } catch (e) {
        throw AIServiceException(
            'Failed to extract text from PDF: ${e.toString()}');
      }
    }

    if (text.trim().isEmpty) {
      throw AIServiceException('No text provided for summary generation.');
    }
    if (text.length > AIConfig.maxInputLength) {
      throw AIServiceException(
          'Text too long. Maximum length is ${AIConfig.maxInputLength} characters.');
    }

    final prompt =
        'Summarize the following text, and provide a title and three relevant tags in JSON format: { "title": "...", "content": "...", "tags": ["...", "...", "..."] }. Text: ${_sanitizeInput(text)}';

    try {
      final response = await _retryWithBackoff(() => _textModel
          .generateContent([Content.text(prompt)]).timeout(
              const Duration(seconds: AIConfig.requestTimeout)));
      if (response.text == null || response.text!.isEmpty) {
        throw AIServiceException('Model returned empty response.');
      }
      final jsonString = _cleanJsonResponse(response.text!);

      // Update usage count for FREE tier users
      if (_iapService != null && userId != null) {
        final isPro = await _iapService.hasProAccess();
        if (!isPro) {
          await _incrementWeeklyUploads(userId);
        }
      }

      return jsonString;
    } on FormatException catch (e) {
      developer.log('JSON parsing error in summary',
          name: 'my_app.ai_service', error: e);
      throw AIServiceException(
          'Failed to parse summary data. Please try again.');
    } on TimeoutException {
      throw AIServiceException('Request timed out. Please try again.');
    } catch (e) {
      developer.log('Error generating summary',
          name: 'my_app.ai_service', error: e);
      throw AIServiceException('Failed to generate summary: ${e.toString()}');
    }
  }

  Future<List<Flashcard>> generateFlashcards(
      model_summary.Summary summary) async {
    final prompt =
        'Based on the following summary, generate a list of flashcards in JSON format: { "flashcards": [{"question": "...", "answer": "..."}] }. Summary: ${_sanitizeInput(summary.content)}';

    try {
      final response = await _retryWithBackoff(() => _textModel
          .generateContent([Content.text(prompt)]).timeout(
              const Duration(seconds: AIConfig.requestTimeout)));
      if (response.text != null) {
        final jsonString = _cleanJsonResponse(response.text!);
        final decoded = json.decode(jsonString);
        final flashcardsData = decoded['flashcards'] as List;

        return flashcardsData.map((data) {
          return Flashcard(
            question: data['question'] as String,
            answer: data['answer'] as String,
          );
        }).toList();
      } else {
        return [];
      }
    } on FormatException catch (e) {
      developer.log('JSON parsing error in flashcards',
          name: 'my_app.ai_service', error: e);
      throw AIServiceException(
          'Failed to parse flashcard data. Please try again.');
    } on TimeoutException {
      throw AIServiceException('Request timed out. Please try again.');
    } catch (e) {
      developer.log('Error generating flashcards',
          name: 'my_app.ai_service', error: e);
      throw AIServiceException(
          'Failed to generate flashcards: ${e.toString()}');
    }
  }

  Future<Quiz> generateQuizFromText(
      String text, String title, String userId) async {
    final prompt =
        'Create a multiple-choice quiz from this text: ${_sanitizeInput(text)}. Return in JSON format: { "questions": [ { "question": "What is...?", "options": ["A", "B", "C", "D"], "correctAnswer": "A" } ] }';

    try {
      final response = await _retryWithBackoff(() => _textModel
          .generateContent([Content.text(prompt)]).timeout(
              const Duration(seconds: AIConfig.requestTimeout)));

      if (response.text == null) {
        throw AIServiceException(
            'Failed to generate quiz: No response from model');
      }

      final jsonString = _cleanJsonResponse(response.text!);
      final decoded = json.decode(jsonString);
      final quizData = decoded as Map<String, dynamic>;
      final questionsData = quizData['questions'] as List;

      final questions = questionsData.map((data) {
        final questionText = data['question'] as String;
        final options = List<String>.from(data['options'] as List);
        final correctAnswer = data['correctAnswer'] as String;
        return QuizQuestion(
          question: questionText,
          options: options,
          correctAnswer: correctAnswer,
        );
      }).toList();

      return Quiz(
        id: '',
        userId: userId,
        title: title,
        questions: questions,
        timestamp: Timestamp.now(),
      );
    } on FormatException catch (e) {
      developer.log('JSON parsing error in quiz',
          name: 'my_app.ai_service', error: e);
      throw AIServiceException('Failed to parse quiz data. Please try again.');
    } on TimeoutException {
      throw AIServiceException('Request timed out. Please try again.');
    } catch (e, s) {
      developer.log('Error generating quiz',
          name: 'my_app.ai_service', error: e, stackTrace: s);
      throw AIServiceException('Failed to generate quiz: ${e.toString()}');
    }
  }

  Future<Quiz> generateQuizFromSummary(model_summary.Summary summary) async {
    return generateQuizFromText(summary.content, summary.title, summary.userId);
  }

  Future<Uint8List?> pickImage() async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      return await pickedFile.readAsBytes();
    }
    return null;
  }

  Future<String> describeImage(Uint8List imageBytes) async {
    final imagePart = InlineDataPart('image/jpeg', imageBytes);
    final promptPart = TextPart('Describe this image.');

    try {
      final response = await _retryWithBackoff(() => _visionModel.generateContent([
            Content.multi([promptPart, imagePart])
          ]).timeout(const Duration(seconds: AIConfig.requestTimeout)));
      return response.text ?? 'Could not describe image.';
    } on TimeoutException {
      throw AIServiceException('Request timed out. Please try again.');
    } catch (e) {
      developer.log('Error describing image',
          name: 'my_app.ai_service', error: e);
      throw AIServiceException('Failed to describe image: ${e.toString()}');
    }
  }

  Future<String> extractTextFromPdf(Uint8List pdfBytes,
      {String? userId}) async {
    // Check usage limits for FREE tier users
    if (_iapService != null && userId != null) {
      final isPro = await _iapService.hasProAccess();
      if (!isPro) {
        final isLimitReached = await _iapService.isUploadLimitReached(userId);
        if (isLimitReached) {
          throw AIServiceException(
              'Weekly upload limit reached. Upgrade to Pro for unlimited access.');
        }
      }
    }

    if (pdfBytes.length > AIConfig.maxPdfSize) {
      throw AIServiceException('PDF file too large. Maximum size is 15MB.');
    }
    try {
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();

      // Update usage count for FREE tier users
      if (_iapService != null && userId != null) {
        final isPro = await _iapService.hasProAccess();
        if (!isPro) {
          await _incrementWeeklyUploads(userId);
        }
      }

      return text;
    } catch (e) {
      developer.log('Error extracting text from PDF',
          name: 'my_app.ai_service', error: e);
      throw AIServiceException(
          'Failed to extract text from PDF: ${e.toString()}');
    }
  }

  Future<String> extractTextFromImage(Uint8List imageBytes,
      {String? userId}) async {
    // Check usage limits for FREE tier users
    if (_iapService != null && userId != null) {
      final isPro = await _iapService.hasProAccess();
      if (!isPro) {
        final isLimitReached = await _iapService.isUploadLimitReached(userId);
        if (isLimitReached) {
          throw AIServiceException(
              'Weekly upload limit reached. Upgrade to Pro for unlimited access.');
        }
      }
    }

    final imagePart = InlineDataPart('image/jpeg', imageBytes);
    final promptPart = TextPart(
        'Transcribe all the text from this image exactly as it appears. Do not add any introductory or concluding remarks.');

    try {
      final response = await _retryWithBackoff(() => _visionModel.generateContent([
            Content.multi([promptPart, imagePart])
          ]).timeout(const Duration(seconds: AIConfig.requestTimeout)));

      if (response.text == null || response.text!.isEmpty) {
        throw AIServiceException('No text found in image.');
      }

      // Update usage count for FREE tier users
      if (_iapService != null && userId != null) {
        final isPro = await _iapService.hasProAccess();
        if (!isPro) {
          await _incrementWeeklyUploads(userId);
        }
      }

      return response.text!;
    } catch (e) {
      developer.log('Error extracting text from image',
          name: 'my_app.ai_service', error: e);
      throw AIServiceException(
          'Failed to extract text from image: ${e.toString()}');
    }
  }

  Future<String> generateOutputs({
    required String text,
    required String title,
    required List<String> requestedOutputs,
    required String userId,
    required LocalDatabaseService localDb,
  }) async {
    // Check usage limits for FREE tier users
    if (_iapService != null) {
      final isPro = await _iapService.hasProAccess();
      if (!isPro) {
        final isUploadLimitReached =
            await _iapService.isUploadLimitReached(userId);
        if (isUploadLimitReached) {
          throw AIServiceException(
              'Weekly upload limit reached. Upgrade to Pro for unlimited access.');
        }

        final isFolderLimitReached =
            await _iapService.isFolderLimitReached(userId);
        if (isFolderLimitReached) {
          throw AIServiceException(
              'Folder limit reached. Upgrade to Pro for unlimited folders.');
        }
      }
    }

    final folderId = const Uuid().v4();
    final folder = Folder(
      id: folderId,
      name: title,
      userId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await localDb.saveFolder(folder);

    if (requestedOutputs.contains('summary')) {
      try {
        final summaryJson = await generateSummary(text, userId: userId);
        final summaryData = json.decode(summaryJson) as Map<String, dynamic>;

        final summaryId = const Uuid().v4();
        final summary = LocalSummary(
          id: summaryId,
          userId: userId,
          title: summaryData['title'] ?? title,
          content: summaryData['content'] ?? '',
          tags: List<String>.from(summaryData['tags'] ?? []),
          timestamp: DateTime.now(),
          isSynced: false,
        );

        await localDb.saveSummary(summary);
        await localDb.assignContentToFolder(
            summaryId, folderId, 'summary', userId);
      } catch (e) {
        developer.log('Error generating summary in orchestrator', error: e);
      }
    }

    if (requestedOutputs.contains('quiz')) {
      try {
        final quizModel = await generateQuizFromText(text, title, userId);

        final quizId = const Uuid().v4();
        final localQuiz = LocalQuiz(
          id: quizId,
          userId: userId,
          title: quizModel.title,
          questions: quizModel.questions
              .map((q) => LocalQuizQuestion(
                    question: q.question,
                    options: q.options,
                    correctAnswer: q.correctAnswer,
                  ))
              .toList(),
          timestamp: DateTime.now(),
          scores: [],
          isSynced: false,
        );

        await localDb.saveQuiz(localQuiz);
        await localDb.assignContentToFolder(quizId, folderId, 'quiz', userId);
      } catch (e) {
        developer.log('Error generating quiz in orchestrator', error: e);
      }
    }

    if (requestedOutputs.contains('flashcards')) {
      try {
        final tempSummary = model_summary.Summary(
          id: 'temp',
          userId: userId,
          title: title,
          content: text,
          tags: [],
          timestamp: Timestamp.now(),
        );

        final cards = await generateFlashcards(tempSummary);

        if (cards.isNotEmpty) {
          final setId = const Uuid().v4();
          final flashcardSet = LocalFlashcardSet(
            id: setId,
            userId: userId,
            title: title,
            flashcards: cards
                .map((c) => LocalFlashcard(
                    question: c.question,
                    answer: c.answer))
                .toList(),
            timestamp: DateTime.now(),
            isSynced: false,
          );
          await localDb.saveFlashcardSet(flashcardSet);
          await localDb.assignContentToFolder(
              setId, folderId, 'flashcards', userId);
        }
      } catch (e) {
        developer.log('Error generating flashcards in orchestrator', error: e);
      }
    }

    // Update usage count for FREE tier users
    if (_iapService != null) {
      final isPro = await _iapService.hasProAccess();
      if (!isPro) {
        await _incrementWeeklyUploads(userId);
      }
    }

    return folderId;
  }

  Future<void> _incrementWeeklyUploads(String userId) async {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(userId);
      await userDoc.update({
        'weeklyUploads': FieldValue.increment(1),
      });
    } catch (e) {
      developer.log('Failed to increment weekly uploads',
          name: 'my_app.ai_service', error: e);
    }
  }

  Future generateAll(String text, {required List<String> requestedOutputs}) async {}
}