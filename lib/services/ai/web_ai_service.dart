import 'dart:async';
import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html;
import 'package:http/http.dart' as http;
import 'package:sumquiz/services/ai/ai_types.dart';
import '../../models/extraction_result.dart';

class WebAIService {
  Future<Result<ExtractionResult>> extractWebpage(String url) async {
    try {
      // Add timeout
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        return Result.error(EnhancedAIServiceException(
          'Failed to fetch webpage (Status \${response.statusCode})'
        ));
      }
      
      // Validate content type
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('text/html')) {
        return Result.error(EnhancedAIServiceException(
          'URL does not point to a webpage (Content-Type: $contentType)'
        ));
      }
      
      // Extract main content intelligently
      final document = html_parser.parse(response.body);
      final cleanText = _extractMainContent(document);
      final title = _extractTitle(document);
      
      // Validate extracted content
      if (cleanText.trim().length < 100) {
        return Result.error(EnhancedAIServiceException(
          'No readable content found. Page may require login or have minimal text.'
        ));
      }
      
      return Result.ok(ExtractionResult(
        text: cleanText,
        suggestedTitle: title,
      ));
    } on TimeoutException {
      return Result.error(EnhancedAIServiceException(
        'Request timed out. The webpage took too long to respond.'
      ));
    } on FormatException {
      return Result.error(EnhancedAIServiceException(
        'Invalid URL format. Please check the URL and try again.'
      ));
    } on SocketException {
      return Result.error(EnhancedAIServiceException(
        'Network error. Please check your internet connection.'
      ));
    } catch (e) {
      return Result.error(EnhancedAIServiceException(
        'Failed to extract webpage: \${e.toString()}'
      ));
    }
  }

  String _extractMainContent(html.Document document) {
    // Remove unwanted elements
    for (var selector in ['script', 'style', 'nav', 'footer', 'header', 'aside', 'iframe', 'noscript']) {
      document.querySelectorAll(selector).forEach((e) => e.remove());
    }
    
    // Try to find main content area (in order of preference)
    final mainContent = document.querySelector('article') ??
        document.querySelector('main') ??
        document.querySelector('[role=\"main\"]') ??
        document.querySelector('.article-content') ??
        document.querySelector('.post-content') ??
        document.querySelector('.entry-content') ??
        document.querySelector('.content') ??
        document.body;
    
    if (mainContent == null) return '';
    
    // Extract and clean text
    String text = mainContent.text ?? '';
    
    // Clean up whitespace
    text = text
        .split('\\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\\n');
    
    return text;
  }

  String _extractTitle(html.Document document) {
    // Try multiple sources for title
    return document.querySelector('meta[property=\"og:title\"]')?.attributes['content'] ??
        document.querySelector('meta[name=\"twitter:title\"]')?.attributes['content'] ??
        document.head?.querySelector('title')?.text?.trim() ??
        'Web Page';
  }
}
