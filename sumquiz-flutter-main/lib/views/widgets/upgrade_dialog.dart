import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/iap_service.dart';

class UpgradeDialog extends StatelessWidget {
  final String featureName;

  const UpgradeDialog({super.key, required this.featureName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Upgrade to Pro to use $featureName'),
      content: const Text(
          'You have reached your daily limit for this feature. Upgrade to Pro for unlimited access.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(context).pop(); // Close dialog first to avoid overlap

            final iapService = context.read<IAPService?>();
            if (iapService != null) {
              try {
                // Navigate to subscription screen
                if (context.mounted) {
                  Navigator.of(context).pushNamed('/subscription');
                }
              } catch (e) {
                // Ignore or log
              }
            }
          },
          child: const Text('Upgrade'),
        ),
      ],
    );
  }
}
