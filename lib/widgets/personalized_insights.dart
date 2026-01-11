import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/pdf_export_service.dart';

class PersonalizedInsights extends StatelessWidget {
  final double averageAccuracy;
  final int totalTimeSpent;
  final int streakDays;
  final int itemsCompletedToday;
  final int dailyGoal;

  const PersonalizedInsights({
    super.key,
    required this.averageAccuracy,
    required this.totalTimeSpent,
    required this.streakDays,
    required this.itemsCompletedToday,
    required this.dailyGoal,
  });

  String _formatTime(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  List<Map<String, dynamic>> _generateInsights(ThemeData theme) {
    final insights = <Map<String, dynamic>>[];

    if (averageAccuracy < 70) {
      insights.add({
        'icon': Icons.trending_down_rounded,
        'color': Colors.orangeAccent,
        'text':
            'Accuracy is at ${averageAccuracy.toStringAsFixed(1)}%. Frequent reviews can boost this.'
      });
    } else if (averageAccuracy >= 90) {
      insights.add({
        'icon': Icons.trending_up_rounded,
        'color': Colors.greenAccent,
        'text':
            'Excellent accuracy of ${averageAccuracy.toStringAsFixed(1)}%! You have a strong grasp of the material.'
      });
    }

    if (totalTimeSpent > 3600) {
      insights.add({
        'icon': Icons.hourglass_bottom_rounded,
        'color': Colors.blueAccent,
        'text':
            'You\'ve invested ${_formatTime(totalTimeSpent)} learning. Great dedication!'
      });
    }

    if (streakDays >= 3) {
      insights.add({
        'icon': Icons.local_fire_department_rounded,
        'color': Colors.redAccent,
        'text':
            '🔥 $streakDays-day streak! Consistency is key to building knowledge.'
      });
    }

    if (dailyGoal > 0 && itemsCompletedToday >= dailyGoal) {
      insights.add({
        'icon': Icons.check_circle_outline_rounded,
        'color': Colors.greenAccent,
        'text': '🎯 Daily goal met! You\'ve surpassed your target.'
      });
    } else if (dailyGoal > 0) {
      final remaining = dailyGoal - itemsCompletedToday;
      insights.add({
        'icon': Icons.flag_circle_rounded,
        'color': Colors.blueAccent,
        'text':
            'Just $remaining more items to hit your daily goal. You can do it!'
      });
    }

    return insights;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context);
    final insights = _generateInsights(theme);

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: theme.colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text('Personalized Insights', style: theme.textTheme.titleLarge),
              const Spacer(),
              if (user != null)
                IconButton(
                  icon: Icon(Icons.download_for_offline_outlined,
                      color: theme.iconTheme.color),
                  onPressed: () => _exportInsights(context, user, insights),
                  tooltip: 'Export Insights (Pro feature)',
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Icon(insight['icon'] as IconData,
                        color: insight['color'] as Color, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text(insight['text'] as String,
                            style: theme.textTheme.bodyMedium)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _exportInsights(BuildContext context, UserModel user,
      List<Map<String, dynamic>> insights) async {
    if (!user.isPro) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Export is a Pro feature. Upgrade to unlock.'),
            action: SnackBarAction(
                label: 'Upgrade',
                onPressed: () {}), // Replace with your upgrade navigation
          ),
        );
      }
      return;
    }

    try {
      final insightText = insights.map((i) => '- ${i['text']}').join('\n');
      final content = 'Personalized Learning Insights\n\n$insightText';
      await PdfExportService()
          .exportTextAsPdf(content, 'My_Insights.pdf', user.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insights exported as PDF.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export insights: $e')),
        );
      }
    }
  }
}
