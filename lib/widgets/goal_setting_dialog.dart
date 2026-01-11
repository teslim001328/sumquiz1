import 'package:flutter/material.dart';

class GoalSettingDialog extends StatefulWidget {
  final int currentGoal;

  const GoalSettingDialog({super.key, required this.currentGoal});

  @override
  State<GoalSettingDialog> createState() => _GoalSettingDialogState();
}

class _GoalSettingDialogState extends State<GoalSettingDialog> {
  late int _selectedGoal;
  late final TextEditingController _customGoalController;

  final List<int> _defaultGoals = [3, 5, 7, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    _selectedGoal = widget.currentGoal;
    _customGoalController = TextEditingController(
        text: _isCustomGoal() ? widget.currentGoal.toString() : '');
  }

  bool _isCustomGoal() {
    return !_defaultGoals.contains(widget.currentGoal);
  }

  @override
  void dispose() {
    _customGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Center(
          child:
              Text('Set Your Daily Goal', style: theme.textTheme.titleLarge)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _defaultGoals.map((goal) {
              final isSelected = _selectedGoal == goal;
              return ChoiceChip(
                label: Text('$goal'),
                labelStyle: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onSecondary
                      : theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedGoal = goal;
                      _customGoalController.clear();
                    });
                  }
                },
                backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.5),
                selectedColor: theme.colorScheme.secondary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                side: BorderSide.none,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _customGoalController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Custom Goal',
              filled: true,
              fillColor: theme.scaffoldBackgroundColor.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              final parsedValue = int.tryParse(value);
              if (parsedValue != null) {
                setState(() => _selectedGoal = parsedValue);
              }
            },
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_selectedGoal),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Save Goal',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSecondary,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
