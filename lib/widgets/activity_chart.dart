import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ActivityChart extends StatelessWidget {
  final List<MapEntry<DateTime, int>> activityData;

  const ActivityChart({super.key, required this.activityData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weeklyData = _prepareWeeklyData(activityData);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: weeklyData.map((d) => d.value).reduce((a, b) => a > b ? a : b) *
              1.2, // Add 20% padding to max Y
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.secondary,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.round()}',
                  TextStyle(
                      color: theme.colorScheme.onSecondary,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final day = weeklyData[value.toInt()].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(DateFormat.E().format(day),
                        style: theme.textTheme.bodySmall),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: weeklyData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data.value.toDouble(),
                  color: theme.colorScheme.secondary,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  List<MapEntry<DateTime, int>> _prepareWeeklyData(
      List<MapEntry<DateTime, int>> rawData) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final Map<DateTime, int> weeklyActivity = {};

    for (int i = 0; i < 7; i++) {
      final day = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day)
          .add(Duration(days: i));
      weeklyActivity[day] = 0;
    }

    for (var entry in rawData) {
      final dateKey = DateTime(entry.key.year, entry.key.month, entry.key.day);
      if (weeklyActivity.containsKey(dateKey)) {
        weeklyActivity[dateKey] = weeklyActivity[dateKey]! + entry.value;
      }
    }

    return weeklyActivity.entries.toList();
  }
}
