import 'dart:convert';
import 'dart:developer' as developer;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:uuid/uuid.dart';

import '../../models/summary_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';
import '../../services/enhanced_ai_service.dart';
import '../../services/usage_service.dart';
import '../widgets/upgrade_dialog.dart';

enum ScreenState { initial, loading, error, success }

class SummaryScreen extends StatefulWidget {
  final LocalSummary? summary;

  const SummaryScreen({super.key, this.summary});

  @override
  SummaryScreenState createState() => SummaryScreenState();
}

class SummaryScreenState extends State<SummaryScreen> {
  final TextEditingController _textController = TextEditingController();
  String? _pdfFileName;
  Uint8List? _pdfBytes;
  ScreenState _state = ScreenState.initial;
  String _summaryContent = '';
  String _summaryTitle = '';
  List<String> _summaryTags = [];
  String _errorMessage = '';
  String _loadingMessage = 'Generating Summary...';
  bool _isGeneratingQuiz = false;

  late final EnhancedAIService _aiService;
  late final LocalDatabaseService _localDbService;

  @override
  void initState() {
    super.initState();
    _aiService = EnhancedAIService();
    _localDbService = LocalDatabaseService();
    _localDbService.init();
    if (widget.summary != null) {
      _summaryContent = widget.summary!.content;
      _summaryTitle = widget.summary!.title;
      _summaryTags = widget.summary!.tags;
      _state = ScreenState.success;
    }
  }

  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _pdfBytes = result.files.single.bytes;
          _pdfFileName = result.files.single.name;
        });
      }
    } catch (e, s) {
      developer.log('Error picking or reading PDF', name: 'summary.screen', error: e, stackTrace: s);
      setState(() {
        _state = ScreenState.error;
        _errorMessage = "Error picking or reading PDF: $e";
      });
    }
  }

  void _generateSummary() async {
    final userModel = Provider.of<UserModel?>(context, listen: false);
    final usageService = Provider.of<UsageService?>(context, listen: false);
    if (userModel == null || usageService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not available. Please log in again.')));
      return;
    }

    if (!userModel.isPro && !(await usageService.canPerformAction('summaries'))) {
      if (mounted) showDialog(context: context, builder: (context) => const UpgradeDialog(featureName: 'summaries'));
      return;
    }

    setState(() {
      _state = ScreenState.loading;
      _loadingMessage = 'Generating summary...';
    });

    try {
       final folderId = await _aiService.generateAndStoreOutputs(
        text: _textController.text,
        title: _summaryTitle.isNotEmpty ? _summaryTitle : 'Summary',
        requestedOutputs: ['summary'],
        userId: userModel.uid,
        localDb: _localDbService,
        onProgress: (message) {
          setState(() {
            _loadingMessage = message;
          });
        },
      );

      final content = await _localDbService.getFolderContents(folderId);
      final summaryId = content.firstWhere((c) => c.contentType == 'summary').contentId;
      final summary = await _localDbService.getSummary(summaryId);

      if (summary != null) {
        if (!userModel.isPro) await usageService.recordAction('summaries');
        setState(() {
          _summaryTitle = summary.title;
          _summaryContent = summary.content;
          _summaryTags = summary.tags;
          _state = ScreenState.success;
        });
      } else {
        throw Exception('Failed to retrieve the generated summary.');
      }
    } catch (e, s) {
      developer.log('An unexpected error occurred during summary generation', name: 'summary.screen', error: e, stackTrace: s);
      setState(() {
        _state = ScreenState.error;
        _errorMessage = "An unexpected error occurred. Please try again.";
      });
    }
  }

  void _retry() => setState(() {
        _state = ScreenState.initial;
        _summaryContent = _summaryTitle = _errorMessage = '';
        _summaryTags = [];
        _textController.clear();
        _pdfBytes = null;
        _pdfFileName = null;
      });

  void _copySummary() {
    Clipboard.setData(ClipboardData(text: _summaryContent));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Summary content copied to clipboard!')));
  }

  void _saveToLibrary() async {
    final user = context.read<UserModel?>();
    if (user == null) return;

    try {
      final summaryToSave = LocalSummary(
        id: const Uuid().v4(),
        userId: user.uid,
        title: _summaryTitle,
        content: _summaryContent,
        tags: _summaryTags,
        timestamp: DateTime.now(),
        isSynced: false,
      );
      await _localDbService.saveSummary(summaryToSave);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Summary saved to library!')));
    } catch (e, s) {
      developer.log('Error saving summary', name: 'summary.screen', error: e, stackTrace: s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving summary.')));
    }
  }

  Future<void> _generateQuiz() async {
    setState(() => _isGeneratingQuiz = true);
    try {
      final user = context.read<UserModel?>();
      if (user == null || _summaryContent.isEmpty) return;

      if (!mounted) return;
      context.push('/quiz', extra: {'initialText': _summaryContent, 'initialTitle': _summaryTitle});

    } catch (e, s) {
      developer.log('Error navigating to quiz generation', name: 'summary.screen', error: e, stackTrace: s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start quiz generation.')));
    } finally {
      if (mounted) setState(() => _isGeneratingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.summary == null ? 'Generate Summary' : 'Summary Details')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ScreenState.loading: return _buildLoadingState();
      case ScreenState.error: return _buildErrorState();
      case ScreenState.success: return _buildSuccessState();
      default: return _buildInitialState();
    }
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_loadingMessage),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    final canGenerate = _textController.text.isNotEmpty || _pdfFileName != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Paste text or upload a file to get started.', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        TextField(
          controller: _textController,
          maxLines: 12,
          decoration: const InputDecoration(hintText: 'Paste your text here...', border: OutlineInputBorder()),
          onChanged: (text) => setState(() {}),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: Text(_pdfFileName ?? 'Upload PDF'),
          onPressed: _pickPdf,
        ),
        if (_pdfFileName != null)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _pdfBytes = _pdfFileName = null),
              child: const Text('Clear PDF', style: TextStyle(color: Colors.redAccent)),
            ),
          ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: canGenerate ? _generateSummary : null,
          icon: const Icon(Icons.summarize_outlined),
          label: const Text('Generate Summary'),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text('Oops! Something went wrong.', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_errorMessage, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _retry, child: const Text('Try Again')),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    final isViewingSaved = widget.summary != null;
    return Column(
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_summaryTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (_summaryTags.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _summaryTags.map((tag) => Chip(label: Text(tag), backgroundColor: Theme.of(context).colorScheme.secondaryContainer)).toList(),
                  ),
                const Divider(height: 32),
                Text(_summaryContent, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        if (!isViewingSaved)
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.copy), onPressed: _copySummary, label: const Text('Copy'))),
              const SizedBox(width: 16),
              Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.library_add), onPressed: _saveToLibrary, label: const Text('Save'))),
            ],
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isGeneratingQuiz ? null : _generateQuiz,
          icon: _isGeneratingQuiz ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : const Icon(Icons.psychology_alt_outlined),
          label: Text(_isGeneratingQuiz ? "Generating Quiz..." : "Generate Quiz from Summary"),
        ),
        const SizedBox(height: 16),
        if (!isViewingSaved)
          Center(child: TextButton(onPressed: _retry, child: const Text('Generate Another Summary'))),
      ],
    );
  }
}
