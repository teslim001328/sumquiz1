import 'dart:async';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:sumquiz/services/ai/ai_types.dart';
import '../../models/extraction_result.dart';

class WebAIService {
  Future<Result<ExtractionResult>> extractWebpage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final articleBody = document.body?.text ?? '';
        final title = document.head?.querySelector('title')?.text ?? 'Web Page';
        return Result.ok(
            ExtractionResult(text: articleBody, suggestedTitle: title));
      } else {
        return Result.error(EnhancedAIServiceException(
            'Failed to fetch webpage. Status code: ${response.statusCode}'));
      }
    } on TimeoutException {
      return Result.error(EnhancedAIServiceException(
          'The request to the webpage timed out.'));
    } catch (e) {
      return Result.error(
          EnhancedAIServiceException('An error occurred: ${e.toString()}'));
    }
  }
}
