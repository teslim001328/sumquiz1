import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InteractivePreviewCard extends StatelessWidget {
  final String question;
  final VoidCallback? onClipPressed;
  
  const InteractivePreviewCard({
    super.key,
    required this.question,
    this.onClipPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with clip icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'INTERACTIVE PREVIEW',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: WebColors.accent,
                  letterSpacing: 1.5,
                ),
              ),
              InkWell(
                onTap: onClipPressed,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: WebColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.content_copy_rounded,
                    size: 20,
                    color: WebColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Question content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: WebColors.backgroundAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WebColors.border.withOpacity(0.5)),
            ),
            child: Text(
              question,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: WebColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                // Navigate to quiz or study session
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Starting interactive session...'),
                    backgroundColor: WebColors.primary,
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Start Session'),
              style: TextButton.styleFrom(
                foregroundColor: WebColors.primary,
                textStyle: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }
}