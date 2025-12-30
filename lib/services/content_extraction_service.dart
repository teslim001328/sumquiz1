import 'package:sumquiz/services/ai_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ContentExtractionService {
  final YoutubeExplode _yt = YoutubeExplode();
  final AIService _aiService;

  ContentExtractionService(this._aiService);

  Future<String> extractContent({
    required String type, // 'text', 'link', 'pdf', 'image'
    dynamic input,
  }) async {
    switch (type) {
      case 'text':
        return input as String;
      case 'link':
        final url = input as String;
        if (_isYoutubeUrl(url)) {
          return await _extractYoutubeTranscript(url);
        } else {
          return await _extractWebContent(url);
        }
      case 'pdf':
        return await _extractFromPdfBytes(input as Uint8List);
      case 'image':
        return await _extractFromImageBytes(input as Uint8List);
      default:
        throw Exception('Unknown content type: $type');
    }
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

  Future<String> _extractFromPdfBytes(Uint8List pdfBytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text.isNotEmpty ? text : '[No text found in PDF]';
    } catch (e) {
      throw Exception('PDF text extraction failed: $e');
    }
  }

  Future<String> _extractFromImageBytes(Uint8List imageBytes) async {
    try {
      return await _aiService.extractTextFromImage(imageBytes);
    } catch (e) {
      throw Exception('OCR failed: $e');
    }
  }

  // Static helpers for simplified usage if needed, though instance methods are preferred for DI
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

  void dispose() {
    _yt.close();
  }
}
