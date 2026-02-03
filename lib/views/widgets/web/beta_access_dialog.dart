import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sumquiz/theme/web_theme.dart';

class BetaAccessDialog extends StatelessWidget {
  const BetaAccessDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WebColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.android, color: WebColors.primary, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'Get Mobile App Early Access',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: WebColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Follow these steps to unlock the app:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: WebColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: WebColors.accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: WebColors.accentOrange.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: WebColors.accentOrange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Use the same Google Account for both steps',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: WebColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildStepTile(
              number: 1,
              title: 'Join Early Access Group',
              subtitle: 'Look for "Join Group" button',
              buttonText: 'Join Group',
              onTap: () => launchUrl(Uri.parse(
                  'https://groups.google.com/g/sumquiz-closed-testers?pli=1')),
            ),
            const SizedBox(height: 16),
            _buildStepTile(
              number: 2,
              title: 'Download App',
              subtitle: 'Available after joining group',
              buttonText: 'Download',
              onTap: () => launchUrl(Uri.parse(
                  'https://play.google.com/store/apps/details?id=com.sumquiz.app&pli=1')),
              isPrimary: true,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(
                  color: WebColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTile({
    required int number,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isPrimary ? WebColors.primary : Colors.white,
              shape: BoxShape.circle,
              border: isPrimary ? null : Border.all(color: WebColors.border),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: isPrimary ? Colors.white : WebColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: WebColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: WebColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isPrimary ? WebColors.primary : Colors.white,
              foregroundColor:
                  isPrimary ? Colors.white : WebColors.textSecondary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isPrimary
                    ? BorderSide.none
                    : BorderSide(color: WebColors.border),
              ),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
