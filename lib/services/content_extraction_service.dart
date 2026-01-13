import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ContentExtractionService {
  final EnhancedAIService _enhancedAiService;

  ContentExtractionService(this._enhancedAiService);

  Future<String> extractContent({
    required String type, // 'text', 'link', 'pdf', 'image'
    dynamic input,
    String? userId,
    bool refineWithAI = true, // Optional AI refinement
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
          // YouTube requires AI for video analysis
          final result = await _enhancedAiService.analyzeYouTubeVideo(url,
              userId: userId);
          if (result is Ok<String>) {
            return result.value;
          } else {
            throw (result as Error).error;
          }
        } else {
          rawText = await _extractWebContent(url);
        }
        break;
      case 'pdf':
        // Use Syncfusion PDF library (no AI needed)
        rawText = await _extractFromPdfBytes(input as Uint8List);
        break;
      case 'image':
        // Use Google ML Kit OCR (no AI needed)
        rawText = await _extractFromImageBytes(input as Uint8List);
        break;
      default:
        throw Exception('Unknown content type: $type');
    }

    // Optional: Refine/Polish the extracted text with AI
    // This cleans up formatting, removes ads, etc.
    if (refineWithAI && rawText.isNotEmpty) {
      try {
        return await _enhancedAiService.refineContent(rawText);
      } catch (e) {
        // If AI refinement fails, return raw text
        return rawText;
      }
    }

    return rawText;
  }

  bool _isYoutubeUrl(String url) {
    return url.contains('youtube.com/watch') ||
        url.contains('youtu.be/') ||
        url.contains('youtube.com/shorts/');
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

  /// Extract text from PDF using Syncfusion PDF library
  /// No AI usage - pure PDF parsing
  Future<String> _extractFromPdfBytes(Uint8List pdfBytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();

      if (text.isEmpty) {
        return '[No text found in PDF. The PDF might contain only images or scanned content.]';
      }

      return text;
    } catch (e) {
      throw Exception('PDF text extraction failed: $e');
    }
  }

  /// Extract text from image using Google ML Kit OCR
  /// No AI usage - free on-device OCR
  Future<String> _extractFromImageBytes(Uint8List imageBytes) async {
    try {
      // Save image to temporary file (required by ML Kit)
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);

      // Initialize text recognizer
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      // Process image
      final inputImage = InputImage.fromFile(tempFile);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      // Clean up
      await textRecognizer.close();
      await tempFile.delete();

      // Extract text
      if (recognizedText.text.isEmpty) {
        return '[No text found in image. The image might not contain readable text.]';
      }

      return recognizedText.text;
    } catch (e) {
      throw Exception(
          'OCR failed: $e. Make sure the image contains clear, readable text.');
    }
  }
}