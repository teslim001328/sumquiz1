import 'package:flutter/material.dart';
import 'package:sumquiz/models/folder.dart';

class FolderCard extends StatelessWidget {
  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const FolderCard({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.folder_rounded,
                  size: 40.0, color: theme.colorScheme.primary),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Updated: ${folder.updatedAt.toLocal().toString().split(' ')[0]}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.grey),
                onPressed: onDelete,
                tooltip: 'Delete Folder',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
