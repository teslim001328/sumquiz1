import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/local_flashcard.dart';
import 'ai_base_service.dart';
import 'dart:developer' as developer;

class GeneratorAIService extends AIBaseService {
  Future<LocalSummary> generateSummary(String text, {String? userId}) async {
    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title': Schema.string(description: 'Clear, topic-focused title'),
          'content': Schema.string(description: 'Detailed study guide in Markdown format'),
          'tags': Schema.array(items: Schema.string(), description: '3-5 relevant keywords'),
        },
        requiredProperties: ['title', 'content', 'tags'],
      ),
    );

    final prompt = '''Create a comprehensive, EXAM-FOCUSED study guide from the provided text.

OUTPUT REQUIREMENTS:
1. **Title**: A professional, topic-focused title.
2. **Content**: Use Markdown formatting for a structured study guide:
   - Use # for the main title, ## for sections, ### for sub-sections.
   - Use bold (**text**) for key terms and definitions.
   - Use bullet points (*) for lists of facts/details.
   - include equations/formulas in blocks if applicable.
3. **Structure**:
   - Start with an "Overview" section.
   - Group information into logical "Key Concepts".
   - Include a "Quick Review" or "Summary Points" section at the end.
   - Add Memory Aids/Mnemonics where helpful.
4. **Tone**: Academic, clear, and informative.

Text: $text''';

    final response = await generateWithRetry(prompt, generationConfig: config);
    final jsonStr = extractJson(response);
    final data = json.decode(jsonStr);

    return LocalSummary(
      id: '', // To be set by caller
      userId: userId ?? '',
      title: data['title'] ?? 'Study Guide',
      content: data['content'] ?? '',
      timestamp: DateTime.now(),
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Future<LocalQuiz> generateQuiz(String text, {String? userId, int questionCount = 10}) async {
    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title': Schema.string(),
          'questions': Schema.array(
            items: Schema.object(
              properties: {
                'question': Schema.string(description: 'Exam-style question'),
                'options': Schema.array(items: Schema.string(), description: '4 distinct options'),
                'correctAnswer': Schema.string(description: 'The exact matching correct option'),
                'explanation': Schema.string(description: 'Detailed explanation of the correct answer'),
              },
              requiredProperties: ['question', 'options', 'correctAnswer', 'explanation'],
            ),
          ),
        },
        requiredProperties: ['title', 'questions'],
      ),
    );

    final prompt = '''Generate a challenging $questionCount-question multiple-choice quiz based on this text.

QUIZ RULES:
1. Questions must require understanding/application, not just simple name/date recall.
2. Options must be plausible distractors related to the topic.
3. Do NOT use "All of the above" or "None of the above" more than once.
4. Explanations must be thorough, explaining WHY the answer is correct and briefly why others are incorrect if applicable.

Text: $text''';

    final response = await generateWithRetry(prompt, customModel: proModel, generationConfig: config);
    final jsonStr = extractJson(response);
    final data = json.decode(jsonStr);

    final questions = (data['questions'] as List).map((q) => LocalQuizQuestion(
      question: q['question'],
      options: List<String>.from(q['options']),
      correctAnswer: q['correctAnswer'],
      explanation: q['explanation'],
    )).toList();

    return LocalQuiz(
      id: '',
      userId: userId ?? '',
      title: data['title'] ?? 'Quick Quiz',
      questions: questions,
      timestamp: DateTime.now(),
    );
  }

  Future<LocalFlashcardSet> generateFlashcards(String text, {String? userId, int cardCount = 15}) async {
    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title': Schema.string(),
          'flashcards': Schema.array(
            items: Schema.object(
              properties: {
                'question': Schema.string(description: 'Concise question or concept'),
                'answer': Schema.string(description: 'Precise answer or definition'),
              },
              requiredProperties: ['question', 'answer'],
            ),
          ),
        },
        requiredProperties: ['title', 'flashcards'],
      ),
    );

    final prompt = '''Create $cardCount active-recall flashcards from the text.

FLASHCARD PRINCIPLES:
- **Atomic Principle**: One question = one idea. Keep answers concise.
- **Clarity**: Use clear, unambiguous language.
- **Focus**: Target high-yield facts, crucial definitions, and pivotal concepts.
- **Variety**: Use a mix of "What is...", "How does...", and "Identify the..." style questions.

Text: $text''';

    final response = await generateWithRetry(prompt, generationConfig: config);
    final jsonStr = extractJson(response);
    final data = json.decode(jsonStr);

    final flashcards = (data['flashcards'] as List).map((f) => LocalFlashcard(
      question: f['question'],
      answer: f['answer'],
    )).toList();

    return LocalFlashcardSet(
      id: '',
      userId: userId ?? '',
      title: data['title'] ?? 'Flashcards',
      flashcards: flashcards,
      timestamp: DateTime.now(),
    );
  }

  Future<String> refineContent(String rawText) async {
    final prompt = '''You are an expert content extractor preparing raw text for exam studying.

CRITICAL: Your task is to EXTRACT and CLEAN the content, NOT to summarize or condense it.

WHAT TO DO:
1. REMOVE completely:
   - Advertisements, promotional content, menus, headers, footers
   - "Like and subscribe" calls, sponsor messages
   - Unrelated tangents or boilerplate text
2. FIX and CLEAN:
   - Broken sentences, formatting issues, OCR errors
3. ORGANIZE:
   - Structure content into logical sections with clear headers
4. PRESERVE (keep everything):
   - ALL factual information, data points, statistics
   - ALL key concepts, definitions, and explanations
   - ALL examples, case studies, formulas, equations
   - ALL step-by-step procedures

Return ONLY valid JSON:
{
  "cleanedText": "The extracted, cleaned, and organized content..."
}

Text: $rawText''';
    try {
      final response = await generateWithRetry(prompt);
      final jsonStr = extractJson(response);
      final data = json.decode(jsonStr);
      return data['cleanedText'] ?? response;
    } catch (e) {
      developer.log('RefineContent error', name: 'GeneratorAIService', error: e);
      return rawText;
    }
  }

  Future<Map<String, dynamic>> generateFromTopic({
    required String topic,
    String depth = 'intermediate',
    int cardCount = 15,
  }) async {
    final depthInstruction = switch (depth) {
      'beginner' => 'Target audience: Complete beginners. Use simple language, avoid jargon.',
      'advanced' => 'Target audience: Advanced learners. Include nuanced details and expert-level insights.',
      _ => 'Target audience: Intermediate learners. Balance theory with practical examples.'
    };

    final prompt = '''You are an expert educator creating comprehensive study materials.
    TOPIC: $topic
    LEVEL: $depthInstruction

    GENERATE:
    1. **TITLE**: Engaging title.
    2. **SUMMARY**: 500-800 words, organized sections, bullet points.
    3. **QUIZ**: 10 multiple-choice questions with 4 options and correctIndex (0-3).
    4. **FLASHCARDS**: $cardCount question-answer pairs.

    Return ONLY valid JSON format:
    {
      "title": "Title",
      "summary": {
        "content": "...",
        "tags": ["tag1", "tag2"]
      },
      "quiz": [
        {
          "question": "...",
          "options": ["A", "B", "C", "D"],
          "correctIndex": 0,
          "explanation": "..."
        }
      ],
      "flashcards": [
        {"question": "...", "answer": "..."}
      ]
    }''';

    final response = await generateWithRetry(prompt, customModel: proModel);
    final jsonStr = extractJson(response);
    return json.decode(jsonStr);
  }

  Future<LocalQuiz> generateExam({
    required String text,
    required String title,
    required String subject,
    required String level,
    required int questionCount,
    required List<String> questionTypes,
    required double difficultyMix,
    String? userId,
  }) async {
    final config = GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'questions': Schema.array(
            items: Schema.object(
              properties: {
                'question': Schema.string(description: 'The exam question text'),
                'type': Schema.string(description: 'Type of question from the requested list'),
                'options': Schema.array(items: Schema.string(), description: 'Required for Multiple Choice or True/False. Null otherwise.'),
                'correctAnswer': Schema.string(description: 'The correct answer or ideal key points for theory'),
                'explanation': Schema.string(description: 'Why this is the answer / Marking scheme guide'),
                'difficulty': Schema.string(description: 'Easy, Medium, or Hard'),
              },
              requiredProperties: ['question', 'type', 'correctAnswer'],
            ),
          ),
        },
        requiredProperties: ['questions'],
      ),
    );

    final difficultyDesc = difficultyMix < 0.4 ? 'Easy' : (difficultyMix > 0.6 ? 'Hard' : 'Mixed');

    final prompt = '''Create a formal exam paper named "$title" for $subject ($level).
    
    PARAMETERS:
    - Total Questions: $questionCount
    - Allowed Types: ${questionTypes.join(', ')}
    - Overall Difficulty: $difficultyDesc
    - Source Material: $text

    REQUIREMENTS:
    1. Distribute questions across the allowed types fairly.
    2. Ensure questions align with the $level academic standard.
    3. Multiple Choice must have EXACTLY 4 options.
    4. True/False must have EXACTLY 2 options (True, False).
    5. Theory/Short Answer should provide a detailed marking guide in the "correctAnswer" field.
    6. Ensure high academic rigor and clarity.

    Source: $text''';

    final response = await generateWithRetry(prompt, customModel: proModel, generationConfig: config);
    final jsonStr = extractJson(response);
    final data = json.decode(jsonStr);

    final questions = (data['questions'] as List).map((q) => LocalQuizQuestion(
      question: q['question'],
      options: q['options'] != null ? List<String>.from(q['options']) : [],
      correctAnswer: q['correctAnswer'],
      explanation: q['explanation'],
    )).toList();

    return LocalQuiz(
      id: '',
      userId: userId ?? '',
      title: title,
      questions: questions,
      timestamp: DateTime.now(),
    );
  }
}
