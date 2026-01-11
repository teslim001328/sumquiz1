import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/local_flashcard_set.dart';
import '../../models/local_flashcard.dart';
import '../../models/user_model.dart';
import '../../services/local_database_service.dart';

class EditFlashcardScreen extends StatefulWidget {
  final LocalFlashcardSet flashcardSet;

  const EditFlashcardScreen({super.key, required this.flashcardSet});

  @override
  State<EditFlashcardScreen> createState() => _EditFlashcardScreenState();
}

class _EditFlashcardScreenState extends State<EditFlashcardScreen> {
  late TextEditingController _titleController;
  late List<TextEditingController> _questionControllers;
  late List<TextEditingController> _answerControllers;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.flashcardSet.title);
    _questionControllers = widget.flashcardSet.flashcards
        .map((flashcard) => TextEditingController(text: flashcard.question))
        .toList();
    _answerControllers = widget.flashcardSet.flashcards
        .map((flashcard) => TextEditingController(text: flashcard.answer))
        .toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _questionControllers) {
      controller.dispose();
    }
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addFlashcard() {
    setState(() {
      _questionControllers.add(TextEditingController());
      _answerControllers.add(TextEditingController());
    });
  }

  void _removeFlashcard(int index) {
    setState(() {
      _questionControllers[index].dispose();
      _answerControllers[index].dispose();
      _questionControllers.removeAt(index);
      _answerControllers.removeAt(index);
    });
  }

  void _saveChanges() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Not logged in.')),
        );
      }
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set title cannot be empty.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    final db = LocalDatabaseService();
    final List<LocalFlashcard> updatedFlashcards = [];

    for (int i = 0; i < _questionControllers.length; i++) {
      final questionText = _questionControllers[i].text.trim();
      final answerText = _answerControllers[i].text.trim();

      if (questionText.isNotEmpty || answerText.isNotEmpty) {
        updatedFlashcards.add(
          LocalFlashcard(
            question: questionText,
            answer: answerText,
          ),
        );
      }
    }

    if (updatedFlashcards.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot save an empty flashcard set.')),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    final updatedSet = LocalFlashcardSet(
      id: widget.flashcardSet.id,
      title: _titleController.text.trim(),
      flashcards: updatedFlashcards,
      timestamp: DateTime.now(),
      userId: user.uid,
      isSynced: false,
    );

    await db.saveFlashcardSet(updatedSet);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flashcard set saved!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Flashcards'),
        actions: [
          IconButton(
            icon: _isSaving
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: theme.colorScheme.onPrimary))
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveChanges,
            tooltip: 'Save Changes',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Set Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    style: theme.textTheme.titleLarge,
                  ),
                  SizedBox(height: 24),
                  _buildFlashcardList(theme),
                ],
              ),
            ),
          ),
          _buildAddCardButton(theme),
        ],
      ),
    );
  }

  Widget _buildFlashcardList(ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _questionControllers.length,
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Card ${index + 1}',
                        style: theme.textTheme.titleMedium),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error),
                      onPressed: () => _removeFlashcard(index),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _questionControllers[index],
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _answerControllers[index],
                  decoration: const InputDecoration(
                    labelText: 'Answer',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddCardButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        icon: Icon(Icons.add),
        label: Text('Add Flashcard'),
        onPressed: _addFlashcard,
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
