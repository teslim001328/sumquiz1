
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';

class CreateContentScreenWeb extends StatefulWidget {
  const CreateContentScreenWeb({super.key});

  @override
  State<CreateContentScreenWeb> createState() => _CreateContentScreenWebState();
}

class _CreateContentScreenWebState extends State<CreateContentScreenWeb> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _textController = TextEditingController();
  final _linkController = TextEditingController();
  String? _fileName;
  Uint8List? _fileBytes;
  bool _isLoading = false;
  String _errorMessage = '';
  String _selectedInputType = 'text'; // Default to text

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _resetInputs() {
    _textController.clear();
    _linkController.clear();
    setState(() {
      _fileName = null;
      _fileBytes = null;
      _errorMessage = '';
    });
  }

  bool _checkProAccess(String feature) {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user != null && !user.isPro) {
      showDialog(
        context: context,
        builder: (_) => UpgradeDialog(featureName: feature),
      );
      return false;
    }
    return true;
  }

  Future<void> _pickFile(String type) async {
    if (!_checkProAccess(type == 'pdf' ? 'PDF Upload' : 'Image Scan')) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: type == 'pdf' ? FileType.custom : FileType.image,
        allowedExtensions: type == 'pdf' ? ['pdf'] : ['jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _fileName = result.files.single.name;
          _fileBytes = result.files.single.bytes;
          _selectedInputType = type;
          _textController.clear();
          _linkController.clear();
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error picking file: $e');
    }
  }

  Future<void> _processAndNavigate() async {
    if (_isLoading) return;

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      setState(() => _errorMessage = 'You must be logged in to create content.');
      return;
    }

    final usageService = UsageService();
    final canGenerate = await usageService.canGenerateDeck(user.uid);

    if (!mounted) return;
    if (!canGenerate) {
      showDialog(
        context: context,
        builder: (_) => const UpgradeDialog(featureName: 'Daily Limit'),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final extractionService = Provider.of<ContentExtractionService>(context, listen: false);
      String extractedText = '';

      switch (_selectedInputType) {
        case 'text':
          if (_textController.text.trim().isEmpty) throw Exception('Text field cannot be empty.');
          extractedText = _textController.text;
          break;
        case 'link':
          if (_linkController.text.trim().isEmpty) throw Exception('URL field cannot be empty.');
           if (!_checkProAccess('Web Link')) {
            setState(() => _isLoading = false);
            return;
          }
          extractedText = await extractionService.extractContent(type: 'link', input: _linkController.text);
          break;
        case 'pdf':
          if (_fileBytes == null) throw Exception('No PDF file selected.');
          extractedText = await extractionService.extractContent(type: 'pdf', input: _fileBytes!);
          break;
        case 'image':
          if (_fileBytes == null) throw Exception('No image file selected.');
          extractedText = await extractionService.extractContent(type: 'image', input: _fileBytes!);
          break;
        default:
          throw Exception('Please provide some content first.');
      }
      
      if (extractedText.trim().isEmpty) {
        throw Exception('Could not extract any content from the source.');
      }

      await usageService.recordDeckGeneration(user.uid);
      if (mounted) context.go('/create/extraction-view', extra: extractedText);

    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: colorScheme.surface, // Use theme color
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Generate Study Materials From Anything', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const SizedBox(height: 16),
                  Text(
                    'Pdfs, links, text, and images can be transformed into flashcards, quizzes, and summaries in seconds.',
                    style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  _buildInputWidget(theme),
                  const SizedBox(height: 24),
                  if (_errorMessage.isNotEmpty)
                    Text(_errorMessage, style: TextStyle(color: colorScheme.error, fontSize: 16)),
                  const SizedBox(height: 24),
                  _buildGenerateButton(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputWidget(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface, // Use theme color
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface, // Use theme color
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
              onTap: (index) {
                _resetInputs();
                setState(() {
                  _selectedInputType = [
                    'text',
                    'link',
                    'pdf',
                    'image'
                  ][index];
                });
              },
              tabs: const [
                Tab(text: 'Paste Text'),
                Tab(text: 'Add Link'),
                Tab(text: 'Upload PDF'),
                Tab(text: 'Upload Image'),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          SizedBox(
            height: 200,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTextField(theme),
                _buildLinkField(theme),
                _buildFileUpload('pdf', theme),
                _buildFileUpload('image', theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _textController,
        maxLines: null,
        expands: true,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Paste your text here...',
          hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
          border: InputBorder.none,
        ),
        onChanged: (_) {
          _resetInputs();
          _selectedInputType = 'text';
        },
      ),
    );
  }

  Widget _buildLinkField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _linkController,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Enter a URL...',
          hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
          border: InputBorder.none,
        ),
        onChanged: (_) {
          _resetInputs();
          _selectedInputType = 'link';
        },
      ),
    );
  }

  Widget _buildFileUpload(String type, ThemeData theme) {
    final colorScheme = theme.colorScheme;

    if (_fileName != null && _selectedInputType == type) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(_fileName!, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return InkWell(
      onTap: () => _pickFile(type),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, size: 40, color: colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text('Click to upload ${type.toUpperCase()}', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: 250,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _processAndNavigate,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Extract Content', // Changed button text
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
