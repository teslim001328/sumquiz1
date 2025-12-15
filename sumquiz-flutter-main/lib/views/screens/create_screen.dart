import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/services/content_extraction_service.dart';
import 'package:myapp/services/iap_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  bool _isLoading = false;

  Future<void> _handlePasteText() async {
    context.push('/extraction');
  }

  Future<void> _handlePasteLink() async {
    final TextEditingController urlController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Enter a YouTube or web article URL to extract content.'),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'https://youtube.com/...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;

              Navigator.pop(context); // Close dialog
              setState(() => _isLoading = true);

              try {
                final extractionService =
                    context.read<ContentExtractionService>();
                final text = await extractionService.extractContent(url);
                if (mounted) {
                  context.push('/extraction', extra: text);
                }
              } catch (e) {
                _showError('Failed to extract content: $e');
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Extract'),
          ),
          /*
          // PRO FEATURE: Link Extraction
          // Replace the above button with this to gate execution:
          ProActionButton(
            featureName: 'Link Extraction',
            child: const Text('Extract'),
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              
              Navigator.pop(context);
              // ... existing logic ...
            },
          ),
          */
        ],
      ),
    );
  }

  Future<void> _handleUploadPdf() async {
    // PRO CHECK: Check Pro access before allowing PDF upload
    final iapService = context.read<IAPService?>();
    if (iapService != null) {
      final isPro = await iapService.hasProAccess();
      if (!isPro && mounted) {
        // Navigate to subscription screen
        if (mounted) {
          context.push('/subscription');
        }
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final aiService = context.read<AIService>();
          try {
            // Note: extractTextFromPdf needs to be implemented in AIService
            // For now, we assume it's there or we'll add it in the Service Layer phase
            final text = await aiService.extractTextFromPdf(file.bytes!);
            if (mounted) {
              context.push('/extraction', extra: text);
            }
          } catch (e) {
            _showError('Failed to extract text: $e');
          }
        }
      }
    } catch (e) {
      _showError('Error picking file: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleScanImage() async {
    setState(() => _isLoading = true);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image != null) {
        final bytes = await image.readAsBytes();
        final aiService = context.read<AIService>();
        try {
          // Note: extractTextFromImage needs to be implemented/exposed in AIService
          final text = await aiService.extractTextFromImage(bytes);
          if (mounted) {
            context.push('/extraction', extra: text);
          }
        } catch (e) {
          _showError('Failed to extract text from image: $e');
        }
      }
    } catch (e) {
      _showError('Error scanning image: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create New'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'What would you like to create today?',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn().slideY(begin: -0.2, end: 0),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView(
                    children: [
                      _buildOptionCard(
                        context,
                        icon: Icons.paste_rounded,
                        title: 'Paste Text',
                        subtitle: 'Type or paste content manually',
                        color: Colors.blue.shade100,
                        iconColor: Colors.blue.shade700,
                        onTap: _handlePasteText,
                        delay: 100,
                      ),
                      const SizedBox(height: 16),
                      _buildOptionCard(
                        context,
                        icon: Icons.link_rounded,
                        title: 'Paste Link',
                        subtitle: 'Extract from YouTube or Web',
                        color: Colors.green.shade100,
                        iconColor: Colors.green.shade700,
                        onTap: _handlePasteLink,
                        delay: 150,
                      ),
                      const SizedBox(height: 16),
                      _buildOptionCard(
                        context,
                        icon: Icons.picture_as_pdf_rounded,
                        title: 'Upload PDF',
                        subtitle: 'Extract text from a PDF document',
                        color: Colors.red.shade100,
                        iconColor: Colors.red.shade700,
                        onTap: _handleUploadPdf,
                        delay: 200,
                      ),
                      const SizedBox(height: 16),
                      _buildOptionCard(
                        context,
                        icon: Icons.camera_alt_rounded,
                        title: 'Scan Image',
                        subtitle: 'Extract text from a photo',
                        color: Colors.purple.shade100,
                        iconColor: Colors.purple.shade700,
                        onTap: _handleScanImage,
                        delay: 300,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    required int delay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Theme.of(context).dividerColor,
              size: 20,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.2, end: 0);
  }
}
