import 'package:flutter/material.dart';

class ExtractionProgressDialog extends StatelessWidget {
  const ExtractionProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      title: Text('Extracting Content'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Please wait while we extract the content from your source.'),
        ],
      ),
    );
  }
}
