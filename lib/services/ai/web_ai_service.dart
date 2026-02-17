import 'dart:async';
import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html;
import 'package:http/http.dart' as http;
import 'package:sumquiz/services/ai/ai_types.dart';
import '../../models/extraction_result.dart';

class WebAIService {
  /// Extract content from a webpage with intelligent content parsing
  Future<Result<ExtractionResult>> extractWebpage(String url) async {
    try {
      // Add timeout to prevent app freezes
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return Result.error(EnhancedAIServiceException(
            'Failed to fetch webpage (Status ${response.statusCode})'));
      }

      // Validate content type
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('text/html')) {
        return Result.error(EnhancedAIServiceException(
            'URL does not point to a webpage (Content-Type: $contentType)'));
      }

      // Parse HTML and extract main content
      final document = html_parser.parse(response.body);
      final cleanText = _extractMainContent(document);
      final title = _extractTitle(document);

      // Validate extracted content
      if (cleanText.trim().length < 100) {
        return Result.error(EnhancedAIServiceException(
            'No readable content found. Page may require login or have minimal text.'));
      }

      return Result.ok(ExtractionResult(
        text: cleanText,
        suggestedTitle: title,
      ));
    } on TimeoutException {
      return Result.error(EnhancedAIServiceException(
          'Request timed out. The webpage took too long to respond.'));
    } on FormatException {
      return Result.error(EnhancedAIServiceException(
          'Invalid URL format. Please check the URL and try again.'));
    } on SocketException {
      return Result.error(EnhancedAIServiceException(
          'Network error. Please check your internet connection.'));
    } catch (e) {
      return Result.error(EnhancedAIServiceException(
          'Failed to extract webpage: ${e.toString()}'));
    }
  }

  /// Extract main content from HTML document, removing boilerplate
  String _extractMainContent(html.Document document) {
    // Remove unwanted elements that pollute content
    final unwantedSelectors = [
      'script',
      'style',
      'nav',
      'footer',
      'header',
      'aside',
      'iframe',
      'noscript',
      'form',
      '.advertisement',
      '.ad',
      '.social-share',
      '.comments',
      '.related-posts'
    ];

    for (var selector in unwantedSelectors) {
      document.querySelectorAll(selector).forEach((e) => e.remove());
    }

    // Try to find main content area (in order of preference)
    final mainContent = document.querySelector('article') ??
        document.querySelector('main') ??
        document.querySelector('[role="main"]') ??
        document.querySelector('.article-content') ??
        document.querySelector('.post-content') ??
        document.querySelector('.entry-content') ??
        document.querySelector('.content') ??
        document.querySelector('#content') ??
        document.body;

    if (mainContent == null) return '';

    // Extract text
    String text = mainContent.text ?? '';

    // Clean up whitespace and formatting
    text = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');

    return text;
  }

  /// Extract title from HTML document using multiple sources
  String _extractTitle(html.Document document) {
    // Try Open Graph title first (most reliable for articles)
    final ogTitle = document
        .querySelector('meta[property="og:title"]')
        ?.attributes['content'];
    if (ogTitle != null && ogTitle.isNotEmpty) return ogTitle.trim();

    // Try Twitter card title
    final twitterTitle = document
        .querySelector('meta[name="twitter:title"]')
        ?.attributes['content'];
    if (twitterTitle != null && twitterTitle.isNotEmpty)
      return twitterTitle.trim();

    // Try H1 heading
    final h1 = document.querySelector('h1')?.text;
    if (h1 != null && h1.trim().isNotEmpty) return h1.trim();

    // Fallback to page title
    final pageTitle = document.head?.querySelector('title')?.text;
    if (pageTitle != null && pageTitle.isNotEmpty) return pageTitle.trim();

    return 'Web Page';
  }
}
