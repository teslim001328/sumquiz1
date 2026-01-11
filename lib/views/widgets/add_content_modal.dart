import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddContentModal extends StatelessWidget {
  const AddContentModal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: <Widget>[
              _buildHeader(context, theme),
              _buildOption(
                context,
                icon: Icons.description_outlined,
                title: 'Create a Summary',
                onTap: () => context.push('/summary'),
              ),
              _buildOption(
                context,
                icon: Icons.quiz_outlined,
                title: 'Create a Quiz',
                onTap: () => context.push('/quiz/new'),
              ),
              _buildOption(
                context,
                icon: Icons.style_outlined,
                title: 'Create Flashcards',
                onTap: () => context.push('/flashcards/new'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Create New Content',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 28),
      title: Text(title, style: theme.textTheme.bodyLarge),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      contentPadding:
          const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
