import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart'; // For Result/ExtractionResult if needed
import 'ai_base_service.dart';
import 'dart:developer' as developer;

class YouTubeAIService extends AIBaseService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<Result<ExtractionResult>> analyzeVideo(String videoUrl) async {
    if (!_isValidYouTubeUrl(videoUrl)) {
      return Result.error(EnhancedAIServiceException('Invalid YouTube URL format.', code: 'INVALID_URL'));
    }

    try {
      final config = GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'title': Schema.string(description: 'A high-quality study session title'),
            'content': Schema.string(description: 'All the extracted educational text from the video'),
          },
          requiredProperties: ['title', 'content'],
        ),
      );

      final prompt = '''Analyze this YouTube video and extract ALL educational content for study purposes.

TASK: Provide a suggested title and all educational content.

CRITICAL INSTRUCTIONS:
1. EXTRACT all instructional content (do NOT summarize)
2. Capture EVERYTHING the instructor teaches:
   - All concepts, definitions, explanations (word-for-word when important)
   - Visual content (slides, diagrams, demonstrations shown in video)
   - Examples, case studies, practice problems
   - Formulas, equations, code, technical details
   - Step-by-step procedures
   - Key timestamps [MM:SS] for important sections

EXCLUDE: intros, promos, sponsor messages, and filler content.

USE your native YouTube indexing and multimodal understanding to "watch" and "listen" to the video content from this URL.

URL: $videoUrl

OUTPUT FORMAT (JSON):
{
  "title": "A high-quality study session title",
  "content": "All the extracted educational text..."
}''';

      final response = await generateWithRetry(prompt, customModel: visionModel, generationConfig: config);
      final jsonStr = extractJson(response);
      final data = json.decode(jsonStr);

      final content = data['content'] ?? response;
      final title = data['title'] ?? 'YouTube Video';

      // Check if the content is too sparse or unhelpful
      if (content.trim().length < 100) {
        developer.log('Native YouTube analysis returned sparse content, trying transcript fallback...', name: 'YouTubeAIService');
        final transcriptResult = await extractTranscript(videoUrl);
        if (transcriptResult is Ok<ExtractionResult>) {
          if (transcriptResult.value.text.length > content.length) {
            return transcriptResult;
          }
        }
      }

      return Result.ok(ExtractionResult(
        text: content,
        suggestedTitle: title,
        sourceUrl: videoUrl,
      ));
    } catch (e) {
      developer.log('YouTube AI Vision Analysis failed, trying transcript fallback...', error: e);
      return extractTranscript(videoUrl);
    }
  }

  Future<Result<ExtractionResult>> extractTranscript(String videoUrl) async {
    try {
      final videoId = _extractVideoId(videoUrl);
      if (videoId == null) throw Exception('Could not extract video ID.');

      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.closedCaptions.getManifest(videoId);
      
      if (manifest.tracks.isEmpty) {
        throw Exception('No captions available for this video.');
      }

      final track = manifest.tracks.first;
      final captions = await _yt.videos.closedCaptions.get(track);
      final transcript = captions.captions.map((c) => c.text).join(' ');

      return Result.ok(ExtractionResult(
        text: transcript,
        suggestedTitle: video.title,
        sourceUrl: videoUrl,
      ));
    } catch (e) {
      return Result.error(EnhancedAIServiceException('Transcript extraction failed: $e', code: 'TRANSCRIPT_FAILED'));
    }
  }

  bool _isValidYouTubeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final validDomains = ['youtube.com', 'www.youtube.com', 'youtu.be', 'm.youtube.com'];
      if (!validDomains.contains(uri.host)) return false;
      return uri.path.contains('/watch') || uri.path.contains('/shorts') || uri.host.contains('youtu.be');
    } catch (_) {
      return false;
    }
  }

  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v'];
      if (uri.path.contains('/shorts/')) {
        final segments = uri.pathSegments;
        final index = segments.indexOf('shorts');
        if (index != -1 && index + 1 < segments.length) return segments[index + 1];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _yt.close();
  }
}
