import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:developer' as developer;

import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/extraction_result.dart';

import 'ai/youtube_ai_service.dart';
import 'ai/web_ai_service.dart';
import 'ai/generator_ai_service.dart';
import 'ai/ai_types.dart';
import 'package:uuid/uuid.dart';
import 'package:sumquiz/models/folder.dart';
import 'package:sumquiz/services/spaced_repetition_service.dart';
import 'package:sumquiz/services/sync_service.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/local_flashcard.dart';
export 'ai/ai_types.dart';

// --- EXCEPTIONS moved to ai_types.dart ---

class EnhancedAIService {
  final IAPService _iapService;
  final YouTubeAIService _youtubeService = YouTubeAIService();
  final WebAIService _webService = WebAIService();
  final GeneratorAIService _generatorService = GeneratorAIService();

  EnhancedAIService({required IAPService iapService}) : _iapService = iapService;

  Future<bool> isServiceHealthy() async {
    return await _generatorService.isServiceHealthy();
  }

  Future<void> _checkUsageLimits(String userId) async {
    final isPro = await _iapService.hasProAccess();
    if (!isPro) {
      if (await _iapService.isUploadLimitReached(userId)) {
        throw EnhancedAIServiceException('Daily upload limit reached. Upgrade to Pro for unlimited uploads.', code: 'UPLOAD_LIMIT_REACHED');
      }
      if (await _iapService.isFolderLimitReached(userId)) {
        throw EnhancedAIServiceException('Folder limit reached. Upgrade to Pro for unlimited folders.', code: 'FOLDER_LIMIT_REACHED');
      }
    }
  }

  // --- PUBLIC API ---

  Future<Result<ExtractionResult>> analyzeYouTubeVideo(String videoUrl, {required String userId}) async {
    await _checkUsageLimits(userId);
    return _youtubeService.analyzeVideo(videoUrl);
  }

  Future<Result<ExtractionResult>> extractYouTubeTranscript(String videoUrl, {required String userId}) async {
    await _checkUsageLimits(userId);
    return _youtubeService.extractTranscript(videoUrl);
  }

  Future<Result<ExtractionResult>> extractWebpageContent({required String url, required String userId}) async {
    await _checkUsageLimits(userId);
    return _webService.extractWebpage(url);
  }

  Future<String> refineContent(String rawText) async {
    return _generatorService.refineContent(rawText);
  }

  Future<LocalSummary> generateSummary({
    required String text,
    required String userId,
    String depth = 'intermediate',
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Generating summary...');
    return _generatorService.generateSummary(text, userId: userId);
  }

  Future<LocalQuiz> generateQuiz({
    required String text,
    required String userId,
    int questionCount = 10,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Generating quiz...');
    return _generatorService.generateQuiz(text, userId: userId, questionCount: questionCount);
  }

  Future<LocalFlashcardSet> generateFlashcards({
    required String text,
    required String userId,
    int cardCount = 15,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Generating flashcards...');
    return _generatorService.generateFlashcards(text, userId: userId, cardCount: cardCount);
  }

  Future<LocalQuiz> generateExam({
    required String text,
    required String title,
    required String subject,
    required String level,
    required int questionCount,
    required List<String> questionTypes,
    required double difficultyMix,
    required String userId,
    void Function(String)? onProgress,
  }) async {
    await _checkUsageLimits(userId);
    onProgress?.call('Generating formal exam paper...');
    return _generatorService.generateExam(
      text: text,
      title: title,
      subject: subject,
      level: level,
      questionCount: questionCount,
      questionTypes: questionTypes,
      difficultyMix: difficultyMix,
      userId: userId,
    );
  }

  Future<Result<ExtractionResult>> analyzeContentFromUrl({
    required String url,
    required String mimeType,
    String? customPrompt,
    required String userId,
  }) async {
    await _checkUsageLimits(userId);
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        return Result.error(EnhancedAIServiceException('Failed to download file. Status: ${response.statusCode}'));
      }
      return analyzeContentFromBytes(
        bytes: response.bodyBytes,
        mimeType: mimeType,
        userId: userId,
        customPrompt: customPrompt,
      );
    } catch (e) {
      return Result.error(EnhancedAIServiceException('Failed to analyze content from URL: $e'));
    }
  }

  Future<Result<ExtractionResult>> analyzeContentFromBytes({
    required Uint8List bytes,
    required String mimeType,
    String? customPrompt,
    required String userId,
  }) async {
    await _checkUsageLimits(userId);
    try {
      if (bytes.isEmpty) return Result.error(EnhancedAIServiceException('File data is empty.', code: 'EMPTY_FILE'));

      final config = GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'title': Schema.string(description: 'Suggested title for this content'),
            'content': Schema.string(description: 'All extracted text from the file'),
          },
          requiredProperties: ['title', 'content'],
        ),
      );

      final contentTypePrompt = _getPromptForContentType(mimeType);
      final prompt = '''$contentTypePrompt
      
${customPrompt ?? 'Extract all educational content from this file for study purposes.'}

OUTPUT FORMAT (JSON):
{
  "title": "Suggested title for this content",
  "content": "All extracted text..."
}''';

      final parts = [
        TextPart(prompt),
        DataPart(mimeType, bytes),
      ];

      final result = await _generatorService.generateMultimodal(parts, customModel: _generatorService.visionModel, generationConfig: config);
      final jsonStr = _generatorService.extractJson(result);
      final data = json.decode(jsonStr);
      
      return Result.ok(ExtractionResult(
        text: data['content'] ?? result,
        suggestedTitle: data['title'] ?? 'Extracted Content',
      ));
    } catch (e) {
      developer.log('Multimodal Analysis failed', name: 'EnhancedAIService', error: e);
      return Result.error(EnhancedAIServiceException('Analysis failed: $e'));
    }
  }

  Future<String> extractTextFromImage(Uint8List bytes, {required String userId}) async {
    await _checkUsageLimits(userId);
    try {
      final parts = [
        TextPart('Transcribe all text from this image exactly as it appears. Include all text content, maintaining original formatting where possible.'),
        DataPart('image/jpeg', bytes),
      ];

      final result = await _generatorService.generateMultimodal(parts, customModel: _generatorService.visionModel);
      return result;
    } catch (e) {
      throw EnhancedAIServiceException('Failed to extract text from image: $e', code: 'EXTRACTION_FAILED');
    }
  }

  String _getPromptForContentType(String mimeType) {
    if (mimeType.contains('pdf')) {
      return '''Extract ALL educational content from this PDF document for study purposes.

INSTRUCTIONS:
1. EXTRACT (not summarize) all text content including:
   - Main body text and paragraphs
   - Headers, titles, and section headings
   - Lists, tables, and structured data
   - Definitions, formulas, examples
   - Code snippets if present

2. ORGANIZE the output with:
   - Clear section headings
   - Preserved structure and hierarchy
   - Bullet points for lists

OUTPUT: Clean, organized content ready for studying.''';
    } else if (mimeType.startsWith('image/')) {
      return '''Analyze this image and extract ALL text and educational content.

INSTRUCTIONS:
1. Transcribe all visible text exactly as it appears
2. Describe any diagrams, charts, or visual information
3. Explain any educational content shown
4. Organize the output clearly

OUTPUT: All text and relevant information from the image.''';
    } else if (mimeType.startsWith('audio/')) {
      return '''Transcribe and summarize this audio content for study purposes.

INSTRUCTIONS:
1. Transcribe all spoken content
2. Identify key educational points
3. Note any important facts, definitions, or examples
4. Organize by topic if multiple subjects are covered

OUTPUT: Complete transcription with key educational content highlighted.''';
    } else if (mimeType.startsWith('video/')) {
      return '''Analyze this video and extract ALL educational content.
      
INSTRUCTIONS:
1. Transcribe all spoken content
2. Describe visual content (slides, diagrams, demonstrations)
3. Note timestamps for key sections: [MM:SS]
4. Extract all facts, concepts, examples covered
5. Organize by topic
6. Use logical headings and bullet points

OUTPUT: Complete educational content from the video, organized for study material generation.''';
    } else if (mimeType.contains('presentation') || mimeType.contains('powerpoint') || mimeType.contains('slides')) {
      return '''Analyze these presentation slides and extract ALL educational content.
      
INSTRUCTIONS:
1. Extract text from every slide
2. Identify the main topic of each slide
3. Preserve the hierarchy (titles, subtitles, body text)
4. Describe any diagrams, charts, or tables if they contain educational data
5. Connect related slides into cohesive sections

OUTPUT: Structured educational content extracted from all slides.''';
    } else if (mimeType.contains('officedocument') || mimeType.contains('msword') || mimeType.contains('wordprocessingml')) {
      return '''Extract ALL educational content from this document for study purposes.
      
INSTRUCTIONS:
1. Transcribe all text body, including headers and subheaders
2. Maintain the document's structure and formatting
3. Extract all definitions, formulas, facts, and examples
4. Organize the output clearly for learning

OUTPUT: Clean, organized content ready for studying.''';
    } else {
      return '''Extract and describe all educational content from this file. 
      
INSTRUCTIONS:
1. Identify the core subject matter
2. Extract all relevant facts, definitions, and concepts
3. Structure the output logically using headings and bullet points
4. Ensure the output is suitable for generating quizzes and summaries

OUTPUT: Structured knowledge extracted from the file.''';
    }
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
    final failures = <String>[];

    try {
      for (String outputType in requestedOutputs) {
        onProgress('Generating ${outputType.capitalize()} (${completed + 1}/$total)...');

        try {
          switch (outputType) {
            case 'summary':
              final summary = await _generatorService.generateSummary(text, userId: userId);
              await localDb.saveSummary(summary, folderId);
              break;

            case 'quiz':
              final quiz = await _generatorService.generateQuiz(text, userId: userId);
              await localDb.saveQuiz(quiz, folderId);
              break;

            case 'flashcards':
              final set = await _generatorService.generateFlashcards(text, userId: userId);
              await localDb.saveFlashcardSet(set, folderId);
              for (final card in set.flashcards) {
                await srsService.scheduleReview(card.id, userId);
              }
              break;
          }

          completed++;
          onProgress('${outputType.capitalize()} complete! ✓');
        } catch (e) {
          developer.log('Failed to generate $outputType', name: 'EnhancedAIService', error: e);
          failures.add(outputType);
          onProgress('${outputType.capitalize()} failed - continuing...');
        }
      }

      if (completed == 0) {
        await localDb.deleteFolder(folderId);
        throw EnhancedAIServiceException('Failed to generate any content. Please try again.', code: 'ALL_GENERATION_FAILED');
      }

      if (failures.isNotEmpty) {
        onProgress('Done! ${failures.length} item(s) failed: ${failures.join(", ")}');
      } else {
        onProgress('All done! 🎉');
      }

      // Trigger sync in background
      SyncService(localDb).syncAllData();

      return folderId;
    } catch (e) {
      onProgress('Error occurred. Cleaning up...');
      await localDb.deleteFolder(folderId);
      rethrow;
    }
  }

  Future<String> generateFromTopic({
    required String topic,
    required String userId,
    required LocalDatabaseService localDb,
    String depth = 'intermediate',
    int cardCount = 15,
    void Function(String)? onProgress,
  }) async {
    await _checkUsageLimits(userId);
    onProgress?.call('Generating comprehensive study materials...');

    try {
      final data = await _generatorService.generateFromTopic(
        topic: topic,
        depth: depth,
        cardCount: cardCount,
      );

      final title = data['title'] as String;
      onProgress?.call('Creating study deck...');

      final folder = Folder(
        id: const Uuid().v4(),
        name: title,
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveFolder(folder);
      final folderId = folder.id;

      // Save Summary
      onProgress?.call('Saving summary...');
      final summaryData = data['summary'] as Map<String, dynamic>;
      final summary = LocalSummary(
        id: const Uuid().v4(),
        userId: userId,
        title: title,
        content: summaryData['content'] as String,
        timestamp: DateTime.now(),
        tags: List<String>.from(summaryData['tags'] ?? []),
      );
      await localDb.saveSummary(summary, folderId);

      // Save Quiz
      onProgress?.call('Saving quiz...');
      final quizData = data['quiz'] as List<dynamic>;
      final questions = quizData.map((q) {
        final options = List<String>.from(q['options']);
        final correctIndex = q['correctIndex'] as int;
        return LocalQuizQuestion(
          question: q['question'] as String,
          options: options,
          correctAnswer: options[correctIndex],
          explanation: q['explanation'] as String?,
        );
      }).toList();

      final quiz = LocalQuiz(
        id: const Uuid().v4(),
        userId: userId,
        title: title,
        questions: questions,
        timestamp: DateTime.now(),
      );
      await localDb.saveQuiz(quiz, folderId);

      // Save Flashcards
      onProgress?.call('Saving flashcards...');
      final flashcardsData = data['flashcards'] as List<dynamic>;
      final flashcards = flashcardsData.map((f) => LocalFlashcard(
        question: f['question'] as String,
        answer: f['answer'] as String,
      )).toList();

      final flashcardSet = LocalFlashcardSet(
        id: const Uuid().v4(),
        userId: userId,
        title: title,
        flashcards: flashcards,
        timestamp: DateTime.now(),
      );
      await localDb.saveFlashcardSet(flashcardSet, folderId);

      // Schedule SRS
      final srsService = SpacedRepetitionService(localDb.getSpacedRepetitionBox());
      for (final card in flashcards) {
        await srsService.scheduleReview(card.id, userId);
      }

      onProgress?.call('Study deck ready!');
      SyncService(localDb).syncAllData();
      return folderId;
    } catch (e) {
      developer.log('Topic generation error', name: 'EnhancedAIService', error: e);
      throw EnhancedAIServiceException('Failed to generate study materials.', code: 'GENERATION_FAILED', originalError: e);
    }
  }

  void dispose() {
    _youtubeService.dispose();
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return '';
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
