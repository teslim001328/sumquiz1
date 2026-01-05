import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class EditCreatorProfileScreen extends StatefulWidget {
  const EditCreatorProfileScreen({super.key});

  @override
  State<EditCreatorProfileScreen> createState() =>
      _EditCreatorProfileScreenState();
}

class _EditCreatorProfileScreenState extends State<EditCreatorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _websiteController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserModel?>();
    final profile = user?.creatorProfile ?? {};
    _nameController = TextEditingController(
        text: profile['displayName'] ?? user?.displayName ?? '');
    _bioController = TextEditingController(text: profile['bio'] ?? '');
    _websiteController = TextEditingController(text: profile['website'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = context.read<UserModel?>();
    if (user == null) return;

    final profile = {
      'displayName': _nameController.text.trim(),
      'bio': _bioController.text.trim(),
      'website': _websiteController.text.trim(),
    };

    try {
      await FirestoreService().updateCreatorProfile(user.uid, profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile Updated Successfully!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Creator Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Link
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/creator_dashboard'),
                  icon: const Icon(Icons.dashboard),
                  label: const Text('View Creator Dashboard'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              Text(
                'Build your public presence.',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Public Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Name cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 200,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: 'Website / Social Link',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save Profile'),
                ),
              ),
            ],
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
        ),
      ),
    );
  }
}
