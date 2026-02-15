import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'ai_base_service.dart';
import 'dart:developer' as developer;

class WebAIService extends AIBaseService {
  Future<Result<ExtractionResult>> extractWebpage(String url) async {
    try {
      final config = GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'title': Schema.string(description: 'The most suitable title for this content'),
            'content': Schema.string(description: 'All the extracted educational text from the webpage'),
          },
          requiredProperties: ['title', 'content'],
        ),
      );

      final prompt = '''You are an expert content extractor for educational purposes.

TASK: Extract ALL educational content from this webpage URL for study purposes.

URL: $url

INSTRUCTIONS:
1. Access and read the full content of this webpage.
2. EXTRACT (not summarize) all educational content including body text, facts, and examples.
3. REMOVE menus, ads, sidebars, footers, "Like and subscribe" calls, and sponsor messages.
4. Preserved all formulas, equations, code snippets, or technical details exactly.

OUTPUT FORMAT (JSON):
{
  "title": "The most suitable title for this content",
  "content": "All the extracted educational text..."
}''';

      final response = await generateWithRetry(prompt, customModel: visionModel, generationConfig: config);
      final jsonStr = extractJson(response);
      final data = json.decode(jsonStr);

      return Result.ok(ExtractionResult(
        text: data['content'] ?? response,
        suggestedTitle: data['title'] ?? 'Webpage Content',
        sourceUrl: url,
      ));
    } catch (e) {
      developer.log('Web AI extraction failed, trying fallback...', error: e);
      return _extractWithFallback(url);
    }
  }

  Future<Result<ExtractionResult>> _extractWithFallback(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Failed to load page');

      final document = parse(response.body);
      final title = document.querySelector('title')?.text ?? 'Webpage';
      
      // Basic text extraction from common content tags
      final contentTags = ['article', 'main', '.content', '#content', 'p'];
      String content = '';
      for (var tag in contentTags) {
        final elements = document.querySelectorAll(tag);
        if (elements.isNotEmpty) {
          content = elements.map((e) => e.text).join('\n');
          break;
        }
      }

      return Result.ok(ExtractionResult(
        text: content.trim(),
        suggestedTitle: title.trim(),
        sourceUrl: url,
      ));
    } catch (e) {
      return Result.error(AIServiceException('Web fallback failed: $e', code: 'WEB_FALLBACK_FAILED'));
    }
  }
}
