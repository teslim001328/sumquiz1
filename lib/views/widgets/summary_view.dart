import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SummaryView extends StatelessWidget {
  final String title;
  final String content;
  final List<String> tags;
  final VoidCallback? onCopy;
  final VoidCallback? onSave;
  final VoidCallback? onGenerateQuiz;
  final bool showActions;

  const SummaryView({
    super.key,
    required this.title,
    required this.content,
    required this.tags,
    this.onCopy,
    this.onSave,
    this.onGenerateQuiz,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        SelectableText(
          title,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ).animate().fadeIn().slideY(begin: -0.2),
        
        const SizedBox(height: 24),
        
        // Tags
        if (tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tag.startsWith('#') ? tag : '#$tag',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ).animate().fadeIn(delay: 100.ms),
        
        if (tags.isNotEmpty) const SizedBox(height: 32),
        
        // Action Buttons (if showing actions)
        if (showActions) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: theme.dividerColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (onSave != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                    label: const Text('Save'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: theme.dividerColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
              if (onGenerateQuiz != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onGenerateQuiz,
                    icon: const Icon(Icons.quiz_rounded, size: 18),
                    label: const Text('Generate Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ).animate().fadeIn(delay: 200.ms),
          
          const SizedBox(height: 32),
          
          Divider(color: theme.dividerColor),
          
          const SizedBox(height: 32),
        ],
        
        // Summary Content
        SelectableText(
          content,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.8,
            color: theme.colorScheme.onSurface,
            fontSize: 16,
          ),
        ).animate().fadeIn(delay: showActions ? 300.ms : 200.ms),
      ],
    );
  }
}