import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StreakCard extends StatelessWidget {
  final int streakDays;

  const StreakCard({super.key, required this.streakDays});

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Streak',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WebColors.textPrimary,
                ),
              ),
              const Icon(Icons.local_fire_department_rounded,
                  color: WebColors.accentOrange, size: 24),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$streakDays',
                style: GoogleFonts.outfit(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: WebColors.accent, // Violet color from design
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'days',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: WebColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Weekly Bubbles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDayBubble('M', true),
              _buildDayBubble('T', true),
              _buildDayBubble('W', true),
              _buildDayBubble('T', true),
              _buildDayBubble('F', false),
              _buildDayBubble('S', false),
              _buildDayBubble('S', false),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1);
  }

  Widget _buildDayBubble(String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color:
                isActive ? WebColors.accent : WebColors.border.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isActive ? Colors.white : WebColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
