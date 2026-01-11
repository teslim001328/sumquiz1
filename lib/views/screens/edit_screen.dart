import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/flashcard.dart';
import '../../models/flashcard_set.dart';
import '../../models/quiz_model.dart';
import '../../models/quiz_question.dart';
import '../../models/summary_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class EditScreen extends StatefulWidget {
  final dynamic item;

  const EditScreen({super.key, required this.item});

  @override
  EditScreenState createState() => EditScreenState();
}

class EditScreenState extends State<EditScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _content;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.item is Summary) {
      _title = widget.item.title;
      _content = widget.item.content;
      _tags = widget.item.tags;
    } else if (widget.item is FlashcardSet) {
      _title = widget.item.title;
      _content = widget.item.flashcards
          .map((f) => '${f.question}\n${f.answer}')
          .join('\n\n');
    } else if (widget.item is Quiz) {
      _title = widget.item.title;
      _content = widget.item.questions
          .map((q) =>
              '${q.question}\n${q.options.join('\n')}\nCorrect: ${q.correctAnswer}')
          .join('\n\n');
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final user = Provider.of<UserModel?>(context, listen: false);
      if (user != null) {
        final firestoreService = FirestoreService();
        if (widget.item is Summary) {
          await firestoreService.updateSummary(
            user.uid,
            widget.item.id,
            _title,
            _content,
            _tags,
          );
        } else if (widget.item is FlashcardSet) {
          final updatedFlashcards = _content.split('\n\n').map((pair) {
            final parts = pair.split('\n');
            return Flashcard(question: parts[0], answer: parts[1]);
          }).toList();
          await firestoreService.updateFlashcardSet(
            user.uid,
            widget.item.id,
            _title,
            updatedFlashcards,
          );
        } else if (widget.item is Quiz) {
          final updatedQuestions = _content.split('\n\n').map((block) {
            final lines = block.split('\n');
            final question = lines[0];
            final options = lines.sublist(1, lines.length - 1);
            final correctAnswer = lines.last.replaceFirst('Correct: ', '');
            return QuizQuestion(
                question: question,
                options: options,
                correctAnswer: correctAnswer);
          }).toList();
          await firestoreService.updateQuiz(
            user.uid,
            widget.item.id,
            _title,
            updatedQuestions,
          );
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.item.runtimeType}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
                onSaved: (value) => _title = value!,
                validator: (value) =>
                    value!.isEmpty ? 'Title cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextFormField(
                  initialValue: _content,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                  ),
                  onSaved: (value) => _content = value!,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
