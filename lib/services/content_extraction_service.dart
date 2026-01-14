import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Types of content that can be extracted from URLs
enum UrlContentType {
  youtube,
  document, // PDF, DOC, DOCX, etc.
  image, // JPEG, PNG, WEBP, etc.
  audio, // MP3, WAV, AAC, etc.
  video, // MP4, MOV, AVI, etc.
  webpage, // Regular HTML
}

class ContentExtractionService {
  final EnhancedAIService _enhancedAiService;

  ContentExtractionService(this._enhancedAiService);

  Future<String> extractContent({
    required String type, // 'text', 'link', 'pdf', 'image'
    dynamic input,
    String? userId,
    bool refineWithAI =
        false, // Skip AI refinement by default - raw text is clean
  }) async {
    String rawText;
    switch (type) {
      case 'text':
        rawText = input as String;
        break;
      case 'link':
        final url = input as String;
        final urlType = _detectUrlType(url);

        switch (urlType) {
          case UrlContentType.youtube:
            // YouTube requires special handling
            if (userId == null) {
              throw Exception('User ID is required for YouTube analysis.');
            }
            final result = await _enhancedAiService.analyzeYouTubeVideo(url,
                userId: userId);
            if (result is Ok<String>) {
              return result.value;
            } else {
              throw (result as Error).error;
            }

          case UrlContentType.document:
          case UrlContentType.image:
          case UrlContentType.audio:
          case UrlContentType.video:
            // NEW: Use Gemini File API for direct URL processing
            if (userId == null) {
              throw Exception('User ID is required for file URL analysis.');
            }
            final mimeType = _getMimeType(url);
            final result = await _enhancedAiService.analyzeContentFromUrl(
              url: url,
              mimeType: mimeType,
              userId: userId,
            );
            if (result is Ok<String>) {
              return result.value;
            } else {
              throw (result as Error).error;
            }

          case UrlContentType.webpage:
            // Regular web scraping for HTML pages
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

  /// Detect the type of content from a URL based on file extension
  UrlContentType _detectUrlType(String url) {
    if (_isYoutubeUrl(url)) {
      return UrlContentType.youtube;
    }

    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();

    // Document extensions
    if (path.endsWith('.pdf') ||
        path.endsWith('.doc') ||
        path.endsWith('.docx') ||
        path.endsWith('.txt') ||
        path.endsWith('.rtf') ||
        path.endsWith('.pptx') ||
        path.endsWith('.xlsx') ||
        path.endsWith('.xls') ||
        path.endsWith('.csv')) {
      return UrlContentType.document;
    }

    // Image extensions
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.heif') ||
        path.endsWith('.heic')) {
      return UrlContentType.image;
    }

    // Audio extensions
    if (path.endsWith('.mp3') ||
        path.endsWith('.wav') ||
        path.endsWith('.aac') ||
        path.endsWith('.flac') ||
        path.endsWith('.ogg') ||
        path.endsWith('.m4a')) {
      return UrlContentType.audio;
    }

    // Video extensions
    if (path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi') ||
        path.endsWith('.webm') ||
        path.endsWith('.flv') ||
        path.endsWith('.mkv') ||
        path.endsWith('.wmv')) {
      return UrlContentType.video;
    }

    // Default to webpage
    return UrlContentType.webpage;
  }

  /// Get MIME type from URL extension
  String _getMimeType(String url) {
    final path = url.toLowerCase();

    // Documents
    if (path.endsWith('.pdf')) return 'application/pdf';
    if (path.endsWith('.doc')) return 'application/msword';
    if (path.endsWith('.docx'))
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (path.endsWith('.txt')) return 'text/plain';
    if (path.endsWith('.rtf')) return 'application/rtf';
    if (path.endsWith('.pptx'))
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (path.endsWith('.xlsx'))
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (path.endsWith('.csv')) return 'text/csv';

    // Images
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    if (path.endsWith('.heif') || path.endsWith('.heic')) return 'image/heif';

    // Audio
    if (path.endsWith('.mp3')) return 'audio/mpeg';
    if (path.endsWith('.wav')) return 'audio/wav';
    if (path.endsWith('.aac')) return 'audio/aac';
    if (path.endsWith('.flac')) return 'audio/flac';
    if (path.endsWith('.ogg')) return 'audio/ogg';
    if (path.endsWith('.m4a')) return 'audio/mp4';

    // Video
    if (path.endsWith('.mp4')) return 'video/mp4';
    if (path.endsWith('.mov')) return 'video/quicktime';
    if (path.endsWith('.avi')) return 'video/x-msvideo';
    if (path.endsWith('.webm')) return 'video/webm';
    if (path.endsWith('.flv')) return 'video/x-flv';
    if (path.endsWith('.mkv')) return 'video/x-matroska';
    if (path.endsWith('.wmv')) return 'video/x-ms-wmv';

    // Default
    return 'application/octet-stream';
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
