import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/models/extraction_result.dart';

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
                            'JSS1',
                            'JSS2',
                            'JSS3',
                            'SS1',
                            'SS2',
                            'SS3',
                            '100 Level',
                            'Custom'
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
                                controller:
                                    TextEditingController(text: _duration),
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
                                    const Icon(Icons.check_circle,
                                        color: Colors.green),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Extracted content preview',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _showFullPreview
                                      ? _sourceMaterial
                                      : '${_sourceMaterial.substring(0, _sourceMaterial.length > 100 ? 100 : _sourceMaterial.length)}...',
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
                                    child: Text(_showFullPreview
                                        ? 'Show Less'
                                        : 'View Full'),
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
                                label: '${(_difficultyValue * 100).round()}%',
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
                                color: (_difficultyValue >= 0.4 &&
                                        _difficultyValue <= 0.6)
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
                            title:
                                const Text('Focus on weak / highlighted areas'),
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
                      onPressed: _sourceMaterial.isNotEmpty
                          ? _generateDraftExam
                          : null,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text(
                        'Generate Draft Exam',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
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

  Future<void> _selectSourceMaterial(String type) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Selecting $type...';
    });

    try {
      FilePickerResult? result;
      FileType fileType;
      List<String>? allowedExtensions;

      if (type == 'PDF') {
        fileType = FileType.custom;
        allowedExtensions = ['pdf'];
      } else if (type == 'Image') {
        fileType = FileType.image;
      } else {
        // Notes / Text not supported via file picker yet
        // Maybe open a text dialog? For now, keep mock or show dialog
        setState(() => _isProcessing = false);
        _showNotesInputDialog();
        return;
      }

      result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        withData: true, // Important for web and direct bytes access
      );

      if (result != null) {
        final file = result.files.single;
        final bytes = file.bytes; // Works for web and if withData is true
        final name = file.name;

        if (bytes != null) {
          setState(() => _processingMessage = 'Extracting content from $name...');
          
          final user = Provider.of<UserModel?>(context, listen: false);
          final enhancedAiService = Provider.of<EnhancedAIService>(context, listen: false);
          final extractionService = ContentExtractionService(enhancedAiService);

          final extractionResult = await extractionService.extractContent(
            type: type.toLowerCase(),
            input: bytes,
            userId: user?.uid,
            mimeType: type == 'PDF' ? 'application/pdf' : 'image/jpeg', // simplified mime assumption
            onProgress: (msg) {
              if (mounted) setState(() => _processingMessage = msg);
            },
          );

          setState(() {
            _sourceMaterial = extractionResult.text;
            _isProcessing = false;
          });
        }
      } else {
         setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting content: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showNotesInputDialog() {
     final textController = TextEditingController();
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Notes'),
        content: TextField(
          controller: textController,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Paste your notes here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _sourceMaterial = textController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Use Notes'),
          ),
        ],
      ),
    );
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
      final user = Provider.of<UserModel?>(context, listen: false);
      if (user == null) throw Exception('User not authenticated');
      
      final enhancedAIService = Provider.of<EnhancedAIService>(context, listen: false);

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
      final quiz = await enhancedAIService.generateExam(
        text: _sourceMaterial,
        title: _titleController.text,
        subject: _subjectController.text,
        level: _selectedLevel,
        questionCount: _numberOfQuestions,
        questionTypes: questionTypes,
        difficultyMix: _difficultyValue,
        userId: user.uid,
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _processingMessage = message;
            });
          }
        },
      );

      final questions = quiz.questions;

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
    super.key,
    required this.examTitle,
    required this.subject,
    required this.classLevel,
    required this.numberOfQuestions,
    required this.duration,
    required this.questionTypes,
    required this.difficultyMix,
    required this.sourceMaterial,
    this.initialQuestions,
  });

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
          );
        } else {
          // For other question types
          return LocalQuizQuestion(
            question:
                'Sample question $index: What is the main purpose of an exam?',
            options: [
              'To evaluate knowledge',
              'To waste time',
              'To confuse students',
              'None of the above'
            ],
            correctAnswer: 'To evaluate knowledge',
            explanation: "Exams are designed to assess a student's understanding of a subject.",
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
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveExam,
            tooltip: 'Save to Library',
          ),
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
                  'Q${index + 1}. (MCQ)',
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
                          );
                        });
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: question.options[optionIndex],
                        decoration: InputDecoration(
                          labelText:
                              'Option ${String.fromCharCode(65 + optionIndex)}',
                          border: const OutlineInputBorder(),
                          suffixIcon: question.correctAnswer ==
                                  question.options[optionIndex]
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : null,
                        ),
                        onChanged: (value) {
                          final newOptions =
                              List<String>.from(question.options);
                          newOptions[optionIndex] = value;

                          // Update correct answer if it was this option
                          String newCorrectAnswer = question.correctAnswer;
                          if (question.correctAnswer ==
                              question.options[optionIndex]) {
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
    debugPrint('Editing question $index');
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
      debugPrint('Error regenerating question: $e');
      debugPrint('Stack trace: $stackTrace');

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

  Future<void> _saveExam() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Saving exam to library...';
    });
    
    try {
      final user = Provider.of<UserModel?>(context, listen: false);
      if (user == null) throw Exception('User not authenticated');
      
      await LocalDatabaseService().init();

      final quiz = LocalQuiz(
        id: const Uuid().v4(),
        title: widget.examTitle,
        questions: _questions,
        timestamp: DateTime.now(),
        userId: user.uid,
        isSynced: false,
      );

      await LocalDatabaseService().saveQuiz(quiz);
      
      setState(() => _isProcessing = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam saved to library!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error saving exam: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving exam'), backgroundColor: Colors.red),
        );
      }
    }
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
    super.key,
    required this.examTitle,
    required this.subject,
    required this.classLevel,
    required this.duration,
    required this.questions,
  });

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
                    onChanged:
                        null, // Always checked since it's the main export option
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
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
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
      _processingMessage = 'Generating PDF...';
    });

    try {
      final doc = pw.Document();

      // Filter and Shuffle Questions
      var processedQuestions = List<LocalQuizQuestion>.from(widget.questions);
      if (_randomizeQuestionOrder) {
        processedQuestions.shuffle();
      }
      if (_randomizeOptions) {
        processedQuestions = processedQuestions.map((q) {
          if (q.questionType == 'Multiple Choice') {
             final opts = List<String>.from(q.options)..shuffle();
             return LocalQuizQuestion(
               question: q.question,
               options: opts,
               correctAnswer: q.correctAnswer, 
               explanation: q.explanation,
               questionType: q.questionType,
             );
          }
          return q;
        }).toList();
      }

      // 1. Exam Paper
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
             return [
               pw.Header(
                 level: 0, 
                 child: pw.Column(
                   crossAxisAlignment: pw.CrossAxisAlignment.center,
                   children: [
                     pw.Text(widget.examTitle, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                     pw.SizedBox(height: 8),
                     pw.Text('${widget.subject} - ${widget.classLevel}', style: const pw.TextStyle(fontSize: 16)),
                     pw.Text('Duration: ${widget.duration} mins', style: const pw.TextStyle(fontSize: 14)),
                     pw.Divider(),
                   ]
                 )
               ),
               ...List.generate(processedQuestions.length, (index) {
                 final q = processedQuestions[index];
                 return pw.Container(
                   margin: const pw.EdgeInsets.only(bottom: 16),
                   child: pw.Column(
                     crossAxisAlignment: pw.CrossAxisAlignment.start,
                     children: [
                       pw.Text('${index + 1}. ${q.question}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                       if (q.questionType == 'Multiple Choice' || q.questionType == 'True/False')
                         pw.Padding(
                           padding: const pw.EdgeInsets.only(left: 16, top: 4),
                           child: pw.Column(
                             crossAxisAlignment: pw.CrossAxisAlignment.start,
                             children: q.options.asMap().entries.map((entry) {
                               final char = String.fromCharCode(65 + entry.key);
                               return pw.Text('$char. ${entry.value}');
                             }).toList(),
                           ),
                         ),
                        if (q.questionType == 'Theory' || q.questionType == 'Short Answer')
                           pw.Padding(
                             padding: const pw.EdgeInsets.only(top: 8),
                             child: pw.Container(height: 40, width: double.infinity, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide()))),
                           ),
                     ],
                   ),
                 );
               })
             ];
          },
        ),
      );

      // 2. Answer Sheet / Marking Scheme (New Page)
      if (_includeAnswerSheet || _includeMarkingScheme) {
         doc.addPage(
           pw.MultiPage(
             pageFormat: PdfPageFormat.a4,
             build: (pw.Context context) {
               return [
                 pw.Header(level: 0, child: pw.Text('ANSWER KEY & MARKING SCHEME', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
                 pw.SizedBox(height: 16),
                 ...List.generate(processedQuestions.length, (index) {
                   final q = processedQuestions[index];
                   return pw.Container(
                     margin: const pw.EdgeInsets.only(bottom: 8),
                     child: pw.Row(
                       crossAxisAlignment: pw.CrossAxisAlignment.start,
                       children: [
                         pw.SizedBox(width: 30, child: pw.Text('${index+1}.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                         pw.Expanded(
                           child: pw.Column(
                             crossAxisAlignment: pw.CrossAxisAlignment.start,
                             children: [
                               pw.Text('Ans: ${q.correctAnswer == 'True' || q.correctAnswer == 'False' ? q.correctAnswer : q.correctAnswer}'),
                               if (_includeMarkingScheme && q.explanation != null && q.explanation!.isNotEmpty)
                                 pw.Text('Explanation: ${q.explanation}', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700, fontSize: 10)),
                             ],
                           )
                         )
                       ]
                     )
                   );
                 })
               ];
             }
           )
         );
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: '${widget.examTitle}.pdf',
      );

      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
      }
    }
  }
}