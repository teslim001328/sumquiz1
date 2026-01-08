import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:developer' as developer;

class ContentExtractionService {
  final YoutubeExplode _yt = YoutubeExplode();
  final EnhancedAIService _enhancedAiService;

  ContentExtractionService(this._enhancedAiService);

  Future<String> extractContent({
    required String type, // 'text', 'link', 'pdf', 'image'
    dynamic input,
  }) async {
    String rawText;
    switch (type) {
      case 'text':
        rawText = input as String;
        break;
      case 'link':
        final url = input as String;
        if (_isYoutubeUrl(url)) {
          try {
            // Priority: Native AI Video Analysis (Visuals + Audio)
            rawText = await _enhancedAiService.analyzeYoutubeVideo(url);
          } catch (e) {
            // Fallback: Transcript Extraction (Text only)
            developer.log(
                'Native video analysis failed, falling back to transcript.',
                error: e,
                name: 'ContentExtractionService');
            rawText = await _extractYoutubeTranscript(url);
          }
        } else {
          rawText = await _extractWebContent(url);
        }
        break;
      case 'pdf':
        rawText = await _extractFromPdfBytes(input as Uint8List);
        break;
      case 'image':
        rawText = await _extractFromImageBytes(input as Uint8List);
        break;
      default:
        throw Exception('Unknown content type: $type');
    }

    // Refine the content using AI to remove noise and ensure it's exam-ready
    return await _enhancedAiService.refineContent(rawText);
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
      return await _enhancedAiService.extractTextFromImage(imageBytes);
    } catch (e) {
      throw Exception('OCR failed: $e');
    }
  }

  void dispose() {
    _yt.close();
  }
}
