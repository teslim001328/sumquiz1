import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/models/daily_mission.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ActiveMissionCard extends StatelessWidget {
  final DailyMission? mission;
  final VoidCallback onStart;
  final VoidCallback? onDetails;

  const ActiveMissionCard({
    super.key,
    required this.mission,
    required this.onStart,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (mission == null) {
      return _buildEmptyState(context);
    }

    // Calculate progress
    final total = mission!.flashcardIds.length;
    final int done = mission!.isCompleted ? total : 0;
    final double overflowProgress = total > 0 ? done / total : 0.0;

    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            // Left Feature Image Area (Purple Gradient in design)
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      WebColors.accent.withOpacity(0.9),
                      WebColors.primary
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Abstract glowing sphere logic
                    Positioned(
                      bottom: -80,
                      child: Container(
                        width: 250,
                        height: 150,
                        decoration: BoxDecoration(
                          color: WebColors.accent.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: WebColors.accent.withOpacity(0.4),
                              blurRadius: 80,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Content Area
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: WebColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ACTIVE MISSION',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: WebColors.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: '$done/$total',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: WebColors.primary,
                                ),
                                children: [
                                  TextSpan(
                                    text: '\nSETS DONE',
                                    style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        color: WebColors.textTertiary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Finish Foundation Module', // Hardcoded as per design for now, or use mission title
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: WebColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete $total quiz sets today to hit your XP target.',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: WebColors.textSecondary,
                      ),
                    ),
                    const Spacer(),

                    // Goal Progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Goal Progress',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: WebColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${(overflowProgress * 100).toInt()}%',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: WebColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: overflowProgress,
                        backgroundColor: WebColors.backgroundAlt,
                        color: WebColors.accent,
                        minHeight: 12,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: onStart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: WebColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              textStyle: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            child: const Text('Continue Mission'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: onDetails ?? () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: WebColors.textPrimary,
                              side: const BorderSide(color: WebColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Details'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.1, curve: Curves.easeOut);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.cardShadow,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: WebColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.rocket_launch_rounded,
                  size: 48, color: WebColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Mission',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: WebColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new goal to get started!',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: WebColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: WebColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              child: const Text('Generate Mission'),
            ),
          ],
        ),
      ),
    );
  }
}
