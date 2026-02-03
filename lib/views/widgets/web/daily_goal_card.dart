import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DailyGoalCard extends StatelessWidget {
  final int goalMinutes; // Daily goal in minutes
  final int timeSpentMinutes; // Time spent today in minutes
  
  const DailyGoalCard({
    super.key,
    required this.goalMinutes,
    required this.timeSpentMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goalMinutes > 0 ? timeSpentMinutes / goalMinutes : 0.0;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final remainingMinutes = (goalMinutes - timeSpentMinutes).clamp(0, goalMinutes);
    
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Goal',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WebColors.textPrimary,
                ),
              ),
              Text(
                '${goalMinutes}M',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: WebColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: clampedProgress,
              backgroundColor: WebColors.backgroundAlt,
              valueColor: AlwaysStoppedAnimation<Color>(
                clampedProgress >= 1.0 ? WebColors.success : WebColors.primary,
              ),
              minHeight: 12,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: WebColors.textSecondary,
                  ),
                  children: [
                    TextSpan(text: '$timeSpentMinutes'),
                    TextSpan(
                      text: 'M SPENT',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: WebColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: WebColors.textSecondary,
                  ),
                  children: [
                    TextSpan(text: '$remainingMinutes'),
                    TextSpan(
                      text: 'M LEFT',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: clampedProgress >= 1.0 
                            ? WebColors.success 
                            : WebColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1);
  }
}