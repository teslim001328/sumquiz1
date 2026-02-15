import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'dart:math' as dart_math;

class CreateContentScreenWeb extends StatefulWidget {
  const CreateContentScreenWeb({super.key});

  @override
  State<CreateContentScreenWeb> createState() => _CreateContentScreenWebState();
}

class _CreateContentScreenWebState extends State<CreateContentScreenWeb>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _textController = TextEditingController();
  final _linkController = TextEditingController();
  String? _fileName;
  Uint8List? _fileBytes;
  bool _isLoading = false;
  String _errorMessage = '';
  String? _fileName;

  String _getMimeTypeFromName(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return 'application/pdf';
      case 'ppt': return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt': return 'text/plain';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'mp3': return 'audio/mpeg';
      case 'wav': return 'audio/wav';
      case 'm4a': return 'audio/mp4';
      default: return 'application/octet-stream';
    }
  }
  String _extractionProgress = 'Preparing to extract content...';
  String _selectedInputType = 'topic'; // Default to topic now

  // Exam Generation State
  String _examLevel = 'Intermediate';
  String _examSubject = 'General';
  final List<String> _selectedQuestionTypes = ['Multiple Choice', 'True/False'];

  // Topic-based learning state
  final _topicController = TextEditingController();
  String _topicDepth = 'intermediate';
  double _topicCardCount = 15;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _textController.dispose();
    _linkController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  void _resetInputs() {
    _textController.clear();
    _linkController.clear();
    _topicController.clear();
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
    String featureName = '';
    if (type == 'pdf') featureName = 'PDF Upload';
    else if (type == 'image') featureName = 'Image Scan';
    else if (type == 'audio') featureName = 'Audio/Speech Analysis';
    else if (type == 'slides') featureName = 'Slides Analysis';

    if (!_checkProAccess(featureName)) return;

    try {
      List<String>? allowedExtensions;
      FileType fileType = FileType.custom;

      if (type == 'pdf') {
        allowedExtensions = ['pdf', 'doc', 'docx', 'txt'];
      } else if (type == 'image') {
        fileType = FileType.image;
      } else if (type == 'audio') {
        allowedExtensions = ['mp3', 'wav', 'm4a', 'aac'];
      } else if (type == 'slides') {
        allowedExtensions = ['ppt', 'pptx', 'odp', 'doc', 'docx', 'txt'];
      } else if (type == 'video') {
        allowedExtensions = ['mp4', 'mov', 'avi', 'webm'];
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
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
      setState(
          () => _errorMessage = 'You must be logged in to create content.');
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
      final extractionService =
          Provider.of<ContentExtractionService>(context, listen: false);
      ExtractionResult? extractionResult;

      switch (_selectedInputType) {
        case 'topic':
          // Handle topic-based generation separately
          await _processTopicGeneration(user);
          return; // Exit early, topic handling is complete
        case 'text':
          if (_textController.text.trim().isEmpty) {
            throw Exception('Text field cannot be empty.');
          }
          extractionResult = ExtractionResult(
            text: _textController.text,
            suggestedTitle: 'Pasted Text',
          );
          break;
        case 'link':
          if (_linkController.text.trim().isEmpty) {
            throw Exception('URL field cannot be empty.');
          }
          if (!_checkProAccess('Web Link')) {
            setState(() => _isLoading = false);
            return;
          }
          extractionResult = await extractionService.extractContent(
            type: 'link',
            input: _linkController.text,
            userId: user.uid,
            onProgress: (message) =>
                setState(() => _extractionProgress = message),
          );
          break;
        case 'pdf':
        case 'slides':
          if (_fileBytes == null) throw Exception('No file selected.');
          extractionResult = await extractionService.extractContent(
            type: 'pdf',
            input: _fileBytes!,
            userId: user.uid,
            mimeType: _getMimeTypeFromName(_fileName!),
            onProgress: (message) =>
                setState(() => _extractionProgress = message),
          );
          break;
        case 'image':
          if (_fileBytes == null) throw Exception('No image file selected.');
          extractionResult = await extractionService.extractContent(
            type: 'image',
            input: _fileBytes!,
            userId: user.uid,
            mimeType: _getMimeTypeFromName(_fileName!),
            onProgress: (message) =>
                setState(() => _extractionProgress = message),
          );
          break;
        case 'audio':
          if (_fileBytes == null) throw Exception('No audio file selected.');
          extractionResult = await extractionService.extractContent(
            type: 'audio',
            input: _fileBytes!,
            userId: user.uid,
            mimeType: _getMimeTypeFromName(_fileName!),
            onProgress: (message) =>
                setState(() => _extractionProgress = message),
          );
          break;
        case 'video':
          if (_fileBytes == null) throw Exception('No video file selected.');
          extractionResult = await extractionService.extractContent(
            type: 'video',
            input: _fileBytes!,
            userId: user.uid,
            mimeType: _getMimeTypeFromName(_fileName!),
            onProgress: (message) =>
                setState(() => _extractionProgress = message),
          );
          break;
        case 'exam':
          await _processExamGeneration(user);
          return;
        default:
          throw Exception('Please provide some content first.');
      }

      if (extractionResult.text.trim().isEmpty) {
        throw Exception('Could not extract any content from the source.');
      }

      await usageService.recordDeckGeneration(user.uid);
      if (mounted) {
        context.push('/create/extraction-view', extra: extractionResult);
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Premium Design: Full screen animated background
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 40),
                _buildMainCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              WebColors.HeroGradient.createShader(bounds),
          child: Text(
            'Tutor AI Creator',
            style: GoogleFonts.outfit(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -2,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Transform any content into structured knowledge.\nSelect your source and let AI do the heavy lifting.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 20,
            color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildMainCard() {
    return Container(
      width: 1100,
      height: 850,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        children: [
          _buildCustomTabBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildTopicInput(),
                  _buildTextInput(),
                  _buildLinkInput(),
                  _buildFileUpload('pdf'),
                  _buildFileUpload('slides'),
                  _buildFileUpload('image'),
                  _buildFileUpload('audio'),
                  _buildFileUpload('video'),
                  _buildExamInput(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
            child: Column(
              children: [
                if (_errorMessage.isNotEmpty) _buildErrorBanner(),
                const SizedBox(height: 24),
                _isLoading ? _buildLoadingState() : _buildGenerateButton(),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          curve: Curves.easeOutCubic,
          duration: 400.ms,
        );
  }

  Widget _buildCustomTabBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        dividerColor: Colors.transparent,
        onTap: (index) {
          _resetInputs();
          setState(() {
            _selectedInputType =
                ['topic', 'text', 'link', 'pdf', 'slides', 'image', 'audio', 'video', 'exam'][index];
          });
        },
        tabs: [
          _buildTabItem(Icons.lightbulb, 'Topic'),
          _buildTabItem(Icons.edit_note, 'Text'),
          _buildTabItem(Icons.link, 'Web'),
          _buildTabItem(Icons.picture_as_pdf, 'PDF'),
          _buildTabItem(Icons.slideshow, 'Slides'),
          _buildTabItem(Icons.image, 'Image'),
          _buildTabItem(Icons.mic, 'Audio'),
          _buildTabItem(Icons.videocam, 'Video'),
          _buildTabItem(Icons.school, 'Exam'),
        ],
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String label) {
    return Tab(
      height: 50,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  // ===========================================================
  // TOPIC-BASED LEARNING
  // ===========================================================

  Widget _buildTopicInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              WebColors.HeroGradient.createShader(bounds),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 64, color: Colors.white),
        ),
        const SizedBox(height: 24),
        Text(
          'Master Any Topic',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: WebColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tell us what you want to learn, and AI will build a complete study deck for you.',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              TextField(
                controller: _topicController,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText:
                      'e.g., "History of the Renaissance", "React Hooks basics"...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Icon(Icons.search_rounded, size: 28),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                ),
              ),
              const SizedBox(height: 40),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('SELECT DIFFICULTY'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildWebDepthChip('Beginner', 'beginner'),
                            const SizedBox(width: 12),
                            _buildWebDepthChip('Intermediate', 'intermediate'),
                            const SizedBox(width: 12),
                            _buildWebDepthChip('Advanced', 'advanced'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                            'DECK SIZE: ${_topicCardCount.toInt()} CARDS'),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            activeTrackColor: WebColors.primary,
                            inactiveTrackColor:
                                WebColors.primary.withOpacity(0.1),
                            thumbColor: WebColors.primary,
                            overlayColor: WebColors.primary.withOpacity(0.1),
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10),
                          ),
                          child: Slider(
                            value: _topicCardCount,
                            min: 5,
                            max: 30,
                            divisions: 5,
                            onChanged: (value) {
                              if (value > 10) {
                                final user = Provider.of<UserModel?>(context, listen: false);
                                if (user != null && !user.isPro) {
                                  showDialog(
                                    context: context,
                                    builder: (_) => const UpgradeDialog(featureName: 'Larger Decks'),
                                  );
                                  return;
                                }
                              }
                              setState(() => _topicCardCount = value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildAIDisclaimer(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).textTheme.labelSmall?.color?.withValues(alpha: 0.5),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildAIDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 20, color: WebColors.primary),
          const SizedBox(width: 12),
          Text(
            'AI-generated content. Verify important facts with trusted sources.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: WebColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDepthChip(String label, String value) {
    final isSelected = _topicDepth == value;
    return GestureDetector(
      onTap: () => setState(() => _topicDepth = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _processTopicGeneration(UserModel user) async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() => _errorMessage = 'Please enter a topic to learn about.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final aiService = Provider.of<EnhancedAIService>(context, listen: false);
      final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
      final usageService = UsageService();

      await usageService.recordDeckGeneration(user.uid);

      final folderId = await aiService.generateFromTopic(
        topic: topic,
        userId: user.uid,
        localDb: localDb,
        depth: _topicDepth,
        cardCount: _topicCardCount.toInt(),
      );

      if (mounted) {
        _resetInputs();
        context.push('/library/results-view/$folderId');
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextInput() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: WebColors.subtleShadow,
      ),
      child: TextField(
        controller: _textController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: GoogleFonts.outfit(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 17,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText:
              'Paste any text content here to summarize and generate study materials...',
          hintStyle: GoogleFonts.outfit(color: WebColors.textTertiary),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(40),
        ),
        onChanged: (_) {
          setState(() => _selectedInputType = 'text');
        },
      ),
    );
  }

  Widget _buildLinkInput() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: WebColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.link_rounded, size: 48, color: WebColors.primary),
        ),
        const SizedBox(height: 24),
        Text(
          'Summarize Webpage',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).textTheme.headlineMedium?.color,
          ),
        ),
        const SizedBox(height: 48),
        Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: TextField(
            controller: _linkController,
            style: GoogleFonts.outfit(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'https://example.com/article...',
              hintStyle: GoogleFonts.outfit(color: WebColors.textTertiary),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Icon(Icons.language_rounded,
                    size: 28, color: WebColors.primary),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              filled: true,
              fillColor: WebColors.backgroundAlt,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: WebColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                    const BorderSide(color: WebColors.primary, width: 2),
              ),
            ),
            onChanged: (_) {
              setState(() => _selectedInputType = 'link');
            },
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _buildSupportedChip(Icons.play_circle_rounded, 'YouTube Videos'),
            _buildSupportedChip(Icons.article_rounded, 'Blog Articles'),
            _buildSupportedChip(Icons.web_rounded, 'Web Pages'),
          ],
        ),
      ],
    );
  }

  Widget _buildSupportedChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: WebColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: WebColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUpload(String type) {
    final hasFile = _fileName != null && _selectedInputType == type;
    if (hasFile) return _buildFilePreview();

    bool isPdf = type == 'pdf';
    bool isAudio = type == 'audio';
    bool isImage = type == 'image';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _pickFile(type),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 80),
            decoration: BoxDecoration(
              color: WebColors.backgroundAlt,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                style: BorderStyle.solid, 
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: WebColors.subtleShadow,
                  ),
                  child: Icon(
                    _getFileUploadIcon(type),
                    size: 64,
                    color: WebColors.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _getFileUploadTitle(type),
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: WebColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _getFileUploadSubtitle(type),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: WebColors.textSecondary,
                  ),
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                duration: 3.seconds,
                color: Colors.white.withOpacity(0.5),
              ),
        ),
      ],
    );
  }

  Widget _buildFilePreview() {
    return Center(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: WebColors.border),
          boxShadow: WebColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF22C55E),
                size: 48,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 32),
            Text(
              'READY TO PROCESS',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: WebColors.primary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _fileName!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: WebColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _fileName = null;
                  _fileBytes = null;
                });
              },
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
              label: Text(
                'Remove File',
                style: TextStyle(color: Colors.red[400]),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade100),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error, color: const Color(0xFFDC2626), size: 20),
          const SizedBox(width: 12),
          Text(
            _errorMessage,
            style: TextStyle(
              color: const Color(0xFFDC2626),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().shake();
  }

  Widget _buildGenerateButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [WebColors.primary, const Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: WebColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _processAndNavigate,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            const Text(
              'Generate Study Material',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.2)),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(WebColors.primary),
            strokeWidth: 4,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _extractionProgress,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: WebColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'AI is processing your content...',
          style: GoogleFonts.outfit(
            color: WebColors.textSecondary,
          ),
        ),
      ],
    );
  }

  IconData _getFileUploadIcon(String type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'slides': return Icons.slideshow_rounded;
      case 'image': return Icons.add_a_photo_rounded;
      case 'audio': return Icons.audiotrack_rounded;
      case 'video': return Icons.videocam_rounded;
      default: return Icons.cloud_upload_outlined;
    }
  }

  String _getFileUploadTitle(String type) {
    switch (type) {
      case 'pdf': return 'Choose a PDF file';
      case 'slides': return 'Upload Presentation';
      case 'image': return 'Select an Image';
      case 'audio': return 'Select Audio File';
      case 'video': return 'Select Video File';
      default: return 'Select File';
    }
  }

  String _getFileUploadSubtitle(String type) {
    switch (type) {
      case 'pdf': return 'Drop your PDF here or click to browse';
      case 'slides': return 'Upload PPT, PPTX, or other presentation slides';
      case 'image': return 'Upload an image with text to turn it into flashcards';
      case 'audio': return 'Upload lecture recordings, notes, or educational audio';
      case 'video': return 'Upload educational video clips, lectures, or tutorials';
      default: return 'Select a file from your device';
    }
  }
}

  // ===========================================================
  // EXAM GENERATION
  // ===========================================================

  Widget _buildExamInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              WebColors.HeroGradient.createShader(bounds),
          child: const Icon(Icons.school_rounded,
              size: 64, color: Colors.white),
        ),
        const SizedBox(height: 24),
        Text(
          'AI Tutor Exam',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: WebColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Generate a comprehensive exam to test your knowledge.',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              TextField(
                controller: _topicController, // Reuse topic controller for simplicity
                style: GoogleFonts.outfit(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g., "Advanced Calculus", "World War II"...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Icon(Icons.menu_book_rounded, size: 28),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                ),
              ),
              const SizedBox(height: 40),
               Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('DIFFICULTY LEVEL'),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _examLevel,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: WebColors.backgroundAlt,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: ['Beginner', 'Intermediate', 'Advanced', 'Expert']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setState(() => _examLevel = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('SUBJECT AREA'),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _examSubject,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: WebColors.backgroundAlt,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: ['General', 'Science', 'History', 'Math', 'Language', 'Programming']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) => setState(() => _examSubject = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _processExamGeneration(UserModel user) async {
    if (!_checkProAccess('Tutor Exam')) return;
    
    // Navigate to the dedicated Exam Creation Screen
    context.push('/exam-creation');
  }

}

// Simple dashed border painter
class DashedRectPainter extends CustomPainter {
  final double strokeWidth;
  final Color color;
  final double gap;

  DashedRectPainter(
      {this.strokeWidth = 2.0, this.color = Colors.grey, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    Paint dashedPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double x = size.width;
    double y = size.height;

    Path topPath = getDashedPath(
      a: const Point(0, 0),
      b: Point(x, 0),
      gap: gap,
    );

    Path rightPath = getDashedPath(
      a: Point(x, 0),
      b: Point(x, y),
      gap: gap,
    );

    Path bottomPath = getDashedPath(
      a: Point(0, y),
      b: Point(x, y),
      gap: gap,
    );

    Path leftPath = getDashedPath(
      a: const Point(0, 0),
      b: Point(0, y),
      gap: gap,
    );

    canvas.drawPath(topPath, dashedPaint);
    canvas.drawPath(rightPath, dashedPaint);
    canvas.drawPath(bottomPath, dashedPaint);
    canvas.drawPath(leftPath, dashedPaint);
  }

  Path getDashedPath({
    required Point a,
    required Point b,
    required double gap,
  }) {
    Size size = Size(b.x - a.x, b.y - a.y);
    Path path = Path();
    path.moveTo(a.x, a.y);
    bool shouldDraw = true;
    Point currentPoint = Point(a.x, a.y);

    num radians = dart_math.atan(size.height / size.width);

    num dx = gap * dart_math.cos(radians);
    num dy = gap * dart_math.sin(radians);

    while (shouldDraw) {
      currentPoint = Point(
        currentPoint.x + dx,
        currentPoint.y + dy,
      );
      if (shouldDraw) {
        path.lineTo(currentPoint.x, currentPoint.y);
      } else {
        path.moveTo(currentPoint.x, currentPoint.y);
      }
      shouldDraw = !shouldDraw;
    }
    return path;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class Point {
  final double x;
  final double y;
  const Point(this.x, this.y);
}
