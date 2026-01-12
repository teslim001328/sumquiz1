import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ContentExtractionService {
  final EnhancedAIService _enhancedAiService;

  ContentExtractionService(this._enhancedAiService);

  Future<String> extractContent({
    required String type, // 'text', 'link', 'pdf', 'image'
    dynamic input,
    String? userId,
  }) async {
    String rawText;
    switch (type) {
      case 'text':
        rawText = input as String;
        break;
      case 'link':
        final url = input as String;
        if (_isYoutubeUrl(url)) {
          if (userId == null) {
            throw Exception('User ID is required for YouTube analysis.');
          }
          return await _enhancedAiService.analyzeYouTubeVideo(url, userId: userId);
        } else {
          rawText = await _extractWebContent(url);
        }
        break;
      case 'pdf':
        rawText = await _extractFromPdfBytes(input as Uint8List);
        break;
      case 'image':
        if (userId == null) {
          throw Exception('User ID is required for image extraction.');
        }
        rawText = await _extractFromImageBytes(input as Uint8List, userId: userId);
        break;
      default:
        throw Exception('Unknown content type: $type');
    }

    // Refine/Polish the extracted text
    return await _enhancedAiService.refineContent(rawText);
  }

  bool _isYoutubeUrl(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
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

  Future<String> _extractFromImageBytes(Uint8List imageBytes, {required String userId}) async {
    try {
      return await _enhancedAiService.extractTextFromImage(imageBytes, userId: userId);
    } catch (e) {
      throw Exception('OCR failed: $e');
    }
  }
}
