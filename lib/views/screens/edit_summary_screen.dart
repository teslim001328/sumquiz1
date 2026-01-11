import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../models/editable_content.dart';
import '../../models/local_summary.dart';
import '../../models/user_model.dart';
import '../../services/local_database_service.dart';

class EditSummaryScreen extends StatefulWidget {
  final EditableContent content;

  const EditSummaryScreen({super.key, required this.content});

  @override
  State<EditSummaryScreen> createState() => _EditSummaryScreenState();
}

class _EditSummaryScreenState extends State<EditSummaryScreen> {
  late TextEditingController _titleController;
  late QuillController _quillController;
  late List<String> _tags;

  bool _isSaving = false;
  bool _isAiThinking = false;
  Timer? _typingTimer;
  bool _showAiTooltip = false;

  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.content.title);
    _tags = List.from(widget.content.tags ?? []);

    // Initialize QuillController - use QuillController.basic() for empty document
    _quillController = QuillController.basic();

    // Load existing content if available
    if (widget.content.content != null && widget.content.content!.isNotEmpty) {
      try {
        final contentJson = jsonDecode(widget.content.content!);
        // Create document from JSON delta
        final doc = Document.fromJson(
            contentJson is List ? contentJson : [contentJson]);
        // Replace the controller's document
        _quillController = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        // Fallback: treat as plain text
        _quillController.document.insert(0, widget.content.content!);
      }
    }

    _quillController.document.changes.listen((_) => _onTyping());
  }

  void _onTyping() {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    setState(() {
      _showAiTooltip = false;
    });
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted &&
          _quillController.document.toPlainText().trim().isNotEmpty) {
        setState(() {
          _showAiTooltip = true;
        });
      }
    });
  }

  void _handleSave() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Not logged in.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    final db = LocalDatabaseService();
    final updatedSummary = LocalSummary(
      id: widget.content.id,
      title: _titleController.text,
      content: jsonEncode(_quillController.document.toDelta().toJson()),
      tags: _tags,
      timestamp: DateTime.now(),
      userId: user.uid,
      isSynced: false,
    );

    await db.saveSummary(updatedSummary);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary saved!')),
      );
      Navigator.of(context).pop();
    }
  }

  void _handleAiAssist() {
    setState(() => _isAiThinking = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isAiThinking = false);
    });
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _showAddTagDialog() {
    final TextEditingController tagController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add a Tag'),
          content: TextField(
            controller: tagController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter tag...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _addTag(tagController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _typingTimer?.cancel();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('Edit Summary'),
      actions: [
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _isSaving
                ? Icon(Icons.check,
                    color: theme.colorScheme.primary,
                    key: const ValueKey('saved'))
                : const Icon(Icons.save_outlined, key: ValueKey('save')),
          ),
          onPressed: _handleSave,
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleField(),
                const SizedBox(height: 12),
                _buildTagsSection(),
                const SizedBox(height: 12),
                Divider(color: Theme.of(context).dividerColor, height: 1),
                const SizedBox(height: 10),
                _buildSummaryField(),
                if (_showAiTooltip)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                    child: Text(
                      'Need help phrasing this? Tap AI Assist.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
        _buildToolbar(),
      ],
    );
  }

  Widget _buildTitleField() {
    final theme = Theme.of(context);
    return TextField(
      controller: _titleController,
      style: theme.textTheme.displaySmall,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: 'Enter title...',
        hintStyle: theme.textTheme.displaySmall?.copyWith(
          color: theme.hintColor,
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ..._tags.map((tag) => Chip(
              label: Text(tag),
              onDeleted: () => _removeTag(tag),
              deleteIcon: const Icon(Icons.close, size: 18),
            )),
        GestureDetector(
          onTap: _showAddTagDialog,
          child: const Chip(
            avatar: Icon(Icons.add, size: 18),
            label: Text('Add Tag'),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryField() {
    final theme = Theme.of(context);

    // Use QuillEditor.basic() with controller and config parameters
    return QuillEditor.basic(
      controller: _quillController,
      config: QuillEditorConfig(
        padding: EdgeInsets.zero,
        scrollable: false,
        autoFocus: false,
        expands: false,
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            theme.textTheme.bodyLarge!,
            HorizontalSpacing.zero,
            const VerticalSpacing(10, 0),
            VerticalSpacing.zero,
            null,
          ),
          placeHolder: DefaultTextBlockStyle(
            theme.textTheme.bodyLarge!.copyWith(color: theme.hintColor),
            HorizontalSpacing.zero,
            const VerticalSpacing(10, 0),
            VerticalSpacing.zero,
            null,
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: QuillSimpleToolbar(
              controller: _quillController,
              config: QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showAlignmentButtons: false,
                showBackgroundColorButton: false,
                showCenterAlignment: false,
                showColorButton: false,
                showCodeBlock: false,
                showDirection: false,
                showFontFamily: false,
                showFontSize: false,
                showHeaderStyle: false,
                showIndent: false,
                showInlineCode: false,
                showJustifyAlignment: false,
                showLeftAlignment: false,
                showLink: true,
                showQuote: false,
                showRightAlignment: false,
                showSearchButton: false,
                showSmallButton: false,
                showStrikeThrough: false,
                showSubscript: false,
                showSuperscript: false,
                showUnderLineButton: true,
                showBoldButton: true,
                showItalicButton: true,
                showListBullets: true,
                showListNumbers: true,
                showListCheck: false,
                showDividers: false,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildAiAssistButton(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAiAssistButton() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondary,
      borderRadius: BorderRadius.circular(16.0),
      child: InkWell(
        onTap: _handleAiAssist,
        borderRadius: BorderRadius.circular(16.0),
        child: _isAiThinking
            ? Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: theme.colorScheme.onSecondary),
                    ),
                    const SizedBox(width: 8),
                    Text('Thinking...',
                        style: TextStyle(color: theme.colorScheme.onSecondary)),
                  ],
                ),
              )
            : Shimmer.fromColors(
                baseColor: theme.colorScheme.onSecondary,
                highlightColor: theme.colorScheme.secondary.withAlpha(150),
                period: const Duration(seconds: 3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('AI Assist',
                          style: TextStyle(
                              color: theme.colorScheme.onSecondary,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
