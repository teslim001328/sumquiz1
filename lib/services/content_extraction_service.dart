import 'package:sumquiz/services/ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;

import '../models/folder.dart';
import '../models/local_summary.dart';
import '../models/local_quiz.dart';
import '../models/local_quiz_question.dart';
import '../models/local_flashcard_set.dart';
import '../models/local_flashcard.dart';

class ContentExtractionService {
  final YoutubeExplode _yt = YoutubeExplode();
  final AIService _aiService;
  final LocalDatabaseService _localDb;

  ContentExtractionService(this._aiService, this._localDb);

  Future<String> extractAndGenerate(
      String source, String title, List<String> requestedOutputs, String userId) async {
    String text;
    if (_isYoutubeUrl(source)) {
      text = await _extractYoutubeTranscript(source);
    } else {
      text = await _extractWebContent(source);
    }

    final folderId = await _generateAndSaveContent(text, title, requestedOutputs, userId);
    return folderId;
  }

  Future<String> _generateAndSaveContent(
      String text, String title, List<String> requestedOutputs, String userId) async {
    final allContent = await _aiService.generateAll(text, requestedOutputs: requestedOutputs);

    final folderId = const Uuid().v4();
    final folder = Folder(
      id: folderId,
      name: title,
      userId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _localDb.saveFolder(folder);

    if (requestedOutputs.contains('summary') && allContent.containsKey('summary')) {
      final summaryData = allContent['summary'] as Map<String, dynamic>;
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
      await _localDb.saveSummary(summary);
      await _localDb.assignContentToFolder(summaryId, folderId, 'summary', userId);
    }

    if (requestedOutputs.contains('quiz') && allContent.containsKey('quiz')) {
      final quizData = allContent['quiz'] as Map<String, dynamic>;
      final questionsData = quizData['questions'] as List;
      final questions = questionsData.map((data) {
        final questionText = data['question'] as String;
        final options = List<String>.from(data['options'] as List);
        final correctAnswer = data['correctAnswer'] as String;
        return LocalQuizQuestion(
          question: questionText,
          options: options,
          correctAnswer: correctAnswer,
        );
      }).toList();

      final quizId = const Uuid().v4();
      final localQuiz = LocalQuiz(
        id: quizId,
        userId: userId,
        title: title,
        questions: questions,
        timestamp: DateTime.now(),
        scores: [],
        isSynced: false,
      );
      await _localDb.saveQuiz(localQuiz);
      await _localDb.assignContentToFolder(quizId, folderId, 'quiz', userId);
    }

    if (requestedOutputs.contains('flashcards') && allContent.containsKey('flashcards')) {
      final flashcardsData = allContent['flashcards'] as Map<String, dynamic>;
      final cardsData = flashcardsData['flashcards'] as List;

      if (cardsData.isNotEmpty) {
        final setId = const Uuid().v4();
        final flashcardSet = LocalFlashcardSet(
          id: setId,
          userId: userId,
          title: title,
          flashcards: cardsData
              .map((c) => LocalFlashcard(
                  question: c['question'] as String,
                  answer: c['answer'] as String))
              .toList(),
          timestamp: DateTime.now(),
          isSynced: false,
        );
        await _localDb.saveFlashcardSet(flashcardSet);
        await _localDb.assignContentToFolder(setId, folderId, 'flashcards', userId);
      }
    }

    return folderId;
  }

  bool _isYoutubeUrl(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  Future<String> _extractYoutubeTranscript(String url) async {
    try {
      final validUrl = _cleanYoutubeUrl(url);
      final videoId = VideoId(validUrl);

      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);
      final trackInfo = manifest.getByLanguage('en');

      if (trackInfo.isNotEmpty) {
        final track = trackInfo.first;
        final subtitles = await _yt.videos.closedCaptions.get(track);
        return subtitles.captions.map((e) => e.text).join(' ');
      } else {
        final video = await _yt.videos.get(videoId);
        return "Title: ${video.title}\nDescription: ${video.description}";
      }
    } catch (e) {
      throw Exception('Could not extract content from YouTube: $e');
    }
  }

  String _cleanYoutubeUrl(String url) {
    if (url.contains('si=')) {
      return url.split('si=')[0];
    }
    return url;
  }

  Future<String> _extractWebContent(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final paragraphs = document.querySelectorAll('p');
        if (paragraphs.isEmpty) {
          return document.body?.text ?? 'No content found.';
        }
        return paragraphs.map((e) => e.text).join('\n\n');
      } else {
        throw Exception('Failed to load page: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Could not extract content from URL: $e');
    }
  }

  static Future<String> extractFromPdfBytes(Uint8List pdfBytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text.isNotEmpty ? text : '[No text found in PDF]';
    } catch (e) {
      return '[PDF text extraction failed: $e]';
    }
  }

  static Future<String> extractFromImageBytes(Uint8List imageBytes) async {
    return '[OCR Text Extracted from Image]';
  }

  void dispose() {
    _yt.close();
  }
}
