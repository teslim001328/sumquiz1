import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AccuracyCard extends StatelessWidget {
  final double accuracy; // 0.0 to 1.0

  const AccuracyCard({super.key, required this.accuracy});

  @override
  Widget build(BuildContext context) {
    // Assuming accuracy is 88% like simple example
    final percentage = (accuracy * 100).toInt();

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
          Text(
            'Accuracy (Last 7 Days)',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WebColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Circular Chart
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 10,
                        color: WebColors.accent.withOpacity(0.1),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: accuracy, // Dynamic
                        strokeWidth: 10,
                        color: WebColors.accent,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: WebColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatRow('Highest', '96%'),
                  const SizedBox(height: 8),
                  _buildStatRow('Lowest', '72%'),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1);
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.outfit(
            color: WebColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: WebColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
