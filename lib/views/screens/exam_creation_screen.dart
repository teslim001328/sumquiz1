import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:uuid/uuid.dart';

class ExamCreationScreen extends StatefulWidget {
  const ExamCreationScreen({super.key});

  @override
  State<ExamCreationScreen> createState() => _ExamCreationScreenState();
}

class _ExamCreationScreenState extends State<ExamCreationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  String _selectedLevel = 'JSS1';
  int _numberOfQuestions = 20;
  String _duration = '60';
  bool _includeMultipleChoice = true;
  bool _includeShortAnswer = false;
  bool _includeTheory = false;
  bool _includeTrueFalse = false;
  double _difficultyValue = 0.5; // Medium difficulty by default
  bool _advancedSettings = false;
  bool _evenTopicCoverage = true;
  bool _focusWeakAreas = false;
  String _sourceMaterial = '';
  bool _showFullPreview = false;
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = Provider.of<UserModel?>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Exam'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_processingMessage),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isProcessing = false;
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Create New Exam',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Turn your teaching materials into an editable test paper.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Basic Info Section
                  _buildSectionCard(
                    title: 'Basic Info',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Exam Title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedLevel,
                          decoration: const InputDecoration(
                            labelText: 'Class / Level',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            'JSS1', 'JSS2', 'JSS3', 'SS1', 'SS2', 'SS3', '100 Level', 'Custom'
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedLevel = newValue!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(text: _duration),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Duration',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _duration = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text('mins'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Source Material Section
                  _buildSectionCard(
                    title: 'Source Material',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Material',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          children: [
                            _buildUploadOption('PDF', Icons.picture_as_pdf, () {
                              _selectSourceMaterial('PDF');
                            }),
                            _buildUploadOption('Scan / Image', Icons.image, () {
                              _selectSourceMaterial('Image');
                            }),
                            _buildUploadOption('Notes', Icons.note_alt, () {
                              _selectSourceMaterial('Notes');
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_sourceMaterial.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Extracted content preview',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _showFullPreview
                                      ? _sourceMaterial
                                      : _sourceMaterial.substring(
                                          0,
                                          _sourceMaterial.length > 100
                                              ? 100
                                              : _sourceMaterial.length,
                                        ) +
                                          '...',
                                  maxLines: _showFullPreview ? null : 3,
                                  style: theme.textTheme.bodySmall,
                                ),
                                if (_sourceMaterial.length > 100) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _showFullPreview = !_showFullPreview;
                                      });
                                    },
                                    child: Text(_showFullPreview ? 'Show Less' : 'View Full'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Question Settings Section
                  _buildSectionCard(
                    title: 'Question Settings',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Number of Questions
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Number of Questions',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_numberOfQuestions',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _numberOfQuestions.toDouble(),
                          min: 5,
                          max: 50,
                          divisions: 45,
                          label: _numberOfQuestions.round().toString(),
                          onChanged: (double value) {
                            setState(() {
                              _numberOfQuestions = value.round();
                            });
                          },
                        ),

                        const SizedBox(height: 24),

                        // Question Types
                        Text(
                          'Question Types',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: [
                            FilterChip(
                              label: const Text('Multiple Choice'),
                              selected: _includeMultipleChoice,
                              onSelected: (selected) {
                                setState(() {
                                  _includeMultipleChoice = selected;
                                });
                              },
                            ),
                            FilterChip(
                              label: const Text('Short Answer'),
                              selected: _includeShortAnswer,
                              onSelected: (selected) {
                                setState(() {
                                  _includeShortAnswer = selected;
                                });
                              },
                            ),
                            FilterChip(
                              label: const Text('Theory / Essay'),
                              selected: _includeTheory,
                              onSelected: (selected) {
                                setState(() {
                                  _includeTheory = selected;
                                });
                              },
                            ),
                            FilterChip(
                              label: const Text('True/False'),
                              selected: _includeTrueFalse,
                              onSelected: (selected) {
                                setState(() {
                                  _includeTrueFalse = selected;
                                });
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Difficulty Mix
                        Text(
                          'Difficulty Mix',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Easy',
                              style: theme.textTheme.bodySmall,
                            ),
                            Expanded(
                              child: Slider(
                                value: _difficultyValue,
                                min: 0.0,
                                max: 1.0,
                                label: (_difficultyValue * 100).round().toString() + '%',
                                onChanged: (double value) {
                                  setState(() {
                                    _difficultyValue = value;
                                  });
                                },
                              ),
                            ),
                            Text(
                              'Hard',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              'Easy ${(100 - (_difficultyValue * 100)).round()}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _difficultyValue < 0.5
                                    ? theme.colorScheme.primary
                                    : theme.disabledColor,
                              ),
                            ),
                            Text(
                              'Medium ${((_difficultyValue * 100) - 50).abs().round()}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: (_difficultyValue >= 0.4 && _difficultyValue <= 0.6)
                                    ? theme.colorScheme.primary
                                    : theme.disabledColor,
                              ),
                            ),
                            Text(
                              'Hard ${(_difficultyValue * 100).round()}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _difficultyValue > 0.5
                                    ? theme.colorScheme.primary
                                    : theme.disabledColor,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Advanced Settings Toggle
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _advancedSettings = !_advancedSettings;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Advanced Settings',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _advancedSettings
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                            ],
                          ),
                        ),

                        if (_advancedSettings) ...[
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            title: const Text('Generate evenly across topics'),
                            value: _evenTopicCoverage,
                            onChanged: (bool? value) {
                              setState(() {
                                _evenTopicCoverage = value!;
                              });
                            },
                          ),
                          CheckboxListTile(
                            title: const Text('Focus on weak / highlighted areas'),
                            value: _focusWeakAreas,
                            onChanged: (bool? value) {
                              setState(() {
                                _focusWeakAreas = value!;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Generate Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _sourceMaterial.isNotEmpty ? _generateDraftExam : null,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text(
                        'Generate Draft Exam',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: theme.disabledColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Editable before export.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption(String title, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _selectSourceMaterial(String type) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Selecting $type...';
    });

    // Simulate file picking process
    // In a real app, this would integrate with file picker
    await Future.delayed(const Duration(seconds: 1));

    // For demo purposes, we'll set a sample text
    setState(() {
      _sourceMaterial = 'This is a sample extracted content from your uploaded material. '
          'It contains important information that will be used to generate exam questions. '
          'The AI will analyze this content to create relevant questions based on the parameters you specified.';
      _isProcessing = false;
    });
  }

  Future<void> _generateDraftExam() async {
    if (_titleController.text.isEmpty || _subjectController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in the exam title and subject'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Generating exam questions...';
    });

    try {
      // Get services from provider with error handling
      final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
      final iapService = Provider.of<IAPService>(context, listen: false);
      final user = Provider.of<UserModel?>(context, listen: false);

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Prepare question types
      final questionTypes = <String>[];
      if (_includeMultipleChoice) questionTypes.add('Multiple Choice');
      if (_includeShortAnswer) questionTypes.add('Short Answer');
      if (_includeTheory) questionTypes.add('Theory');
      if (_includeTrueFalse) questionTypes.add('True/False');

      // Check if question types are selected
      if (questionTypes.isEmpty) {
        throw Exception('Please select at least one question type');
      }

      // Generate the exam using AI service
      // This is a simplified version - in a real implementation, this would call the actual AI service
      await Future.delayed(const Duration(seconds: 2)); // Simulate processing time

      // Create mock questions based on the parameters
      final questions = _generateMockQuestions();

      // Navigate to the question editor screen
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => QuestionEditorScreen(
              examTitle: _titleController.text,
              subject: _subjectController.text,
              classLevel: _selectedLevel,
              numberOfQuestions: _numberOfQuestions,
              duration: int.tryParse(_duration) ?? 60,
              questionTypes: questionTypes,
              difficultyMix: _difficultyValue,
              sourceMaterial: _sourceMaterial,
              initialQuestions: questions,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      // Log the actual error and stack trace for debugging
      print('Error generating exam: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating exam: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<LocalQuizQuestion> _generateMockQuestions() {
    final questions = <LocalQuizQuestion>[];

    // Calculate how many questions of each type to generate
    final questionTypes = <String>[];
    if (_includeMultipleChoice) questionTypes.add('Multiple Choice');
    if (_includeShortAnswer) questionTypes.add('Short Answer');
    if (_includeTheory) questionTypes.add('Theory');
    if (_includeTrueFalse) questionTypes.add('True/False');

    // If no question types are selected, default to Multiple Choice
    if (questionTypes.isEmpty) {
      questionTypes.add('Multiple Choice');
    }

    for (int i = 0; i < _numberOfQuestions; i++) {
      final typeIndex = i % questionTypes.length;
      final type = questionTypes[typeIndex];

      if (type == 'Multiple Choice') {
        questions.add(LocalQuizQuestion(
          question: 'Sample MCQ $i: What is the capital of Nigeria?',
          options: ['Lagos', 'Abuja', 'Kano', 'Ibadan'],
          correctAnswer: 'Abuja',
          explanation: 'Abuja became the capital of Nigeria in 1991.',
          questionType: 'Multiple Choice',
        ));
      } else if (type == 'True/False') {
        questions.add(LocalQuizQuestion(
          question: 'Sample T/F $i: Nigeria gained independence in 1960.',
          options: ['True', 'False'],
          correctAnswer: 'True',
          explanation: 'Nigeria gained independence from British colonial rule on October 1, 1960.',
          questionType: 'True/False',
        ));
      } else {
        // For simplicity, default to MCQ for other types in this mock
        questions.add(LocalQuizQuestion(
          question: 'Sample question $i: What is the main purpose of an exam?',
          options: ['To evaluate knowledge', 'To waste time', 'To confuse students', 'None of the above'],
          correctAnswer: 'To evaluate knowledge',
          explanation: 'Exams are designed to assess a student\'s understanding of a subject.',
          questionType: type,
        ));
      }
    }

    return questions;
  }
}

class QuestionEditorScreen extends StatefulWidget {
  final String examTitle;
  final String subject;
  final String classLevel;
  final int numberOfQuestions;
  final int duration;
  final List<String> questionTypes;
  final double difficultyMix;
  final String sourceMaterial;
  final List<LocalQuizQuestion>? initialQuestions;

  const QuestionEditorScreen({
    Key? key,
    required this.examTitle,
    required this.subject,
    required this.classLevel,
    required this.numberOfQuestions,
    required this.duration,
    required this.questionTypes,
    required this.difficultyMix,
    required this.sourceMaterial,
    this.initialQuestions,
  }) : super(key: key);

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  late List<LocalQuizQuestion> _questions;
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  void initState() {
    super.initState();
    _questions = widget.initialQuestions ?? [];
    
    // If no initial questions were provided, generate mock questions
    if (_questions.isEmpty) {
      _generateMockQuestions();
    }
  }

  void _generateMockQuestions() {
    _questions = List.generate(
      widget.numberOfQuestions,
      (index) {
        final typeIndex = index % widget.questionTypes.length;
        final type = widget.questionTypes[typeIndex];
        
        if (type == 'Multiple Choice') {
          return LocalQuizQuestion(
            question: 'Sample MCQ $index: What is the capital of Nigeria?',
            options: ['Lagos', 'Abuja', 'Kano', 'Ibadan'],
            correctAnswer: 'Abuja',
            explanation: 'Abuja became the capital of Nigeria in 1991.',
            questionType: 'Multiple Choice',
          );
        } else if (type == 'True/False') {
          return LocalQuizQuestion(
            question: 'Sample T/F $index: Nigeria gained independence in 1960.',
            options: ['True', 'False'],
            correctAnswer: 'True',
            explanation: 'Nigeria gained independence from British colonial rule on October 1, 1960.',
            questionType: 'True/False',
          );
        } else {
          // For other question types
          return LocalQuizQuestion(
            question: 'Sample question $index: What is the main purpose of an exam?',
            options: ['To evaluate knowledge', 'To waste time', 'To confuse students', 'None of the above'],
            correctAnswer: 'To evaluate knowledge',
            explanation: 'Exams are designed to assess a student\'s understanding of a subject.',
            questionType: type,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _exportExam,
            child: const Text('Export Exam'),
          ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_processingMessage),
                ],
              ),
            )
          : Column(
              children: [
                // Top bar with exam info
                Container(
                  padding: const EdgeInsets.all(16),
                  color: theme.cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.examTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Total Questions: ${_questions.length}',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              'Estimated Duration: ${widget.duration} mins',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addQuestion,
                        tooltip: 'Add Question',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Questions list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      // Simulate refreshing questions
                      await Future.delayed(const Duration(seconds: 1));
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        return _buildQuestionCard(index);
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final theme = Theme.of(context);
    final question = _questions[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Q${index + 1}. (${question.questionType ?? 'MCQ'})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editQuestion(index),
                  tooltip: 'Edit',
                  color: theme.colorScheme.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _regenerateQuestion(index),
                  tooltip: 'Regenerate',
                  color: theme.colorScheme.secondary,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteQuestion(index),
                  tooltip: 'Delete',
                  color: theme.colorScheme.error,
                ),
              ],
            ),
            TextFormField(
              initialValue: question.question,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _questions[index] = LocalQuizQuestion(
                    question: value,
                    options: question.options,
                    correctAnswer: question.correctAnswer,
                    explanation: question.explanation,
                    questionType: question.questionType,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            ...List.generate(
              question.options.length,
              (optionIndex) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Radio<String>(
                      value: question.options[optionIndex],
                      groupValue: question.correctAnswer,
                      onChanged: (value) {
                        setState(() {
                          _questions[index] = LocalQuizQuestion(
                            question: question.question,
                            options: question.options,
                            correctAnswer: value!,
                            explanation: question.explanation,
                            questionType: question.questionType,
                          );
                        });
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: question.options[optionIndex],
                        decoration: InputDecoration(
                          labelText: 'Option ${String.fromCharCode(65 + optionIndex)}',
                          border: const OutlineInputBorder(),
                          suffixIcon: question.correctAnswer == question.options[optionIndex]
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                        ),
                        onChanged: (value) {
                          final newOptions = List<String>.from(question.options);
                          newOptions[optionIndex] = value;
                          
                          // Update correct answer if it was this option
                          String newCorrectAnswer = question.correctAnswer;
                          if (question.correctAnswer == question.options[optionIndex]) {
                            newCorrectAnswer = value;
                          }
                          
                          setState(() {
                            _questions[index] = LocalQuizQuestion(
                              question: question.question,
                              options: newOptions,
                              correctAnswer: newCorrectAnswer,
                              explanation: question.explanation,
                              questionType: question.questionType,
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: question.explanation,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'Explanation (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _questions[index] = LocalQuizQuestion(
                    question: question.question,
                    options: question.options,
                    correctAnswer: question.correctAnswer,
                    explanation: value,
                    questionType: question.questionType,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editQuestion(int index) {
    // In a real implementation, this might open a detailed edit dialog
    // For now, the inline editing is already available in the card
    print('Editing question $index');
  }

  Future<void> _regenerateQuestion(int index) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Regenerating question ${index + 1}...';
    });

    try {
      // Simulate AI regeneration process
      await Future.delayed(const Duration(seconds: 1));

      // In a real implementation, this would call the AI service to regenerate the specific question
      final oldQuestion = _questions[index];
      final regeneratedQuestion = LocalQuizQuestion(
        question: 'Regenerated: ${oldQuestion.question}',
        options: oldQuestion.options.map((option) => 'New: $option').toList(),
        correctAnswer: oldQuestion.options.first, // Reset to first option
        explanation: 'This question was regenerated by AI.',
        questionType: oldQuestion.questionType,
      );

      setState(() {
        _questions[index] = regeneratedQuestion;
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question regenerated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      // Log the actual error and stack trace for debugging
      print('Error regenerating question: $e');
      print('Stack trace: $stackTrace');
      
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating question: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question deleted'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _addQuestion() {
    setState(() {
      _questions.add(LocalQuizQuestion(
        question: 'New question...',
        options: ['Option A', 'Option B', 'Option C', 'Option D'],
        correctAnswer: 'Option A',
        explanation: 'Explanation for the new question',
        questionType: 'Multiple Choice',
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New question added'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _exportExam() {
    // Navigate to export options screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExportOptionsScreen(
          examTitle: widget.examTitle,
          subject: widget.subject,
          classLevel: widget.classLevel,
          duration: widget.duration,
          questions: _questions,
        ),
      ),
    );
  }
}

class ExportOptionsScreen extends StatefulWidget {
  final String examTitle;
  final String subject;
  final String classLevel;
  final int duration;
  final List<LocalQuizQuestion> questions;

  const ExportOptionsScreen({
    Key? key,
    required this.examTitle,
    required this.subject,
    required this.classLevel,
    required this.duration,
    required this.questions,
  }) : super(key: key);

  @override
  State<ExportOptionsScreen> createState() => _ExportOptionsScreenState();
}

class _ExportOptionsScreenState extends State<ExportOptionsScreen> {
  bool _includeAnswerSheet = false;
  bool _includeMarkingScheme = false;
  bool _randomizeQuestionOrder = false;
  bool _randomizeOptions = false;
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Exam'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_processingMessage),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export Exam',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Export options
                  CheckboxListTile(
                    title: const Text('PDF (Printable)'),
                    value: true,
                    onChanged: null, // Always checked since it's the main export option
                    secondary: const Icon(Icons.picture_as_pdf),
                  ),
                  const SizedBox(height: 16),

                  CheckboxListTile(
                    title: const Text('Include answer sheet'),
                    value: _includeAnswerSheet,
                    onChanged: (bool? value) {
                      setState(() {
                        _includeAnswerSheet = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  CheckboxListTile(
                    title: const Text('Include marking scheme'),
                    value: _includeMarkingScheme,
                    onChanged: (bool? value) {
                      setState(() {
                        _includeMarkingScheme = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  CheckboxListTile(
                    title: const Text('Randomize question order'),
                    value: _randomizeQuestionOrder,
                    onChanged: (bool? value) {
                      setState(() {
                        _randomizeQuestionOrder = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  CheckboxListTile(
                    title: const Text('Randomize options'),
                    value: _randomizeOptions,
                    onChanged: (bool? value) {
                      setState(() {
                        _randomizeOptions = value!;
                      });
                    },
                  ),

                  const Spacer(),

                  // Download PDF button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _downloadPdf,
                      icon: const Icon(Icons.download),
                      label: const Text(
                        'Download PDF',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _downloadPdf() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Preparing your exam for download...';
    });

    try {
      // Simulate PDF generation process
      await Future.delayed(const Duration(seconds: 2));

      // Process questions based on selected options
      var processedQuestions = List<LocalQuizQuestion>.from(widget.questions);
      
      if (_randomizeQuestionOrder) {
        processedQuestions.shuffle();
      }
      
      if (_randomizeOptions) {
        processedQuestions = processedQuestions.map((question) {
          final shuffledOptions = List<String>.from(question.options)..shuffle();
          // Need to update correct answer to match new option positions
          final newCorrectAnswer = shuffledOptions[question.options.indexOf(question.correctAnswer)];
          return LocalQuizQuestion(
            question: question.question,
            options: shuffledOptions,
            correctAnswer: newCorrectAnswer,
            explanation: question.explanation,
            questionType: question.questionType,
          );
        }).toList();
      }

      // In a real implementation, this would use a PDF generation library like pdf package
      // For now, we'll simulate the process
      
      setState(() {
        _isProcessing = false;
      });

      // Show success message
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Successful'),
            content: const Text('Your exam has been exported successfully!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  // Pop all screens back to the main screen
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

    } catch (e, stackTrace) {
      // Log the actual error and stack trace for debugging
      print('Error exporting PDF: $e');
      print('Stack trace: $stackTrace');
      
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Failed'),
            content: Text('There was an error exporting your exam: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}