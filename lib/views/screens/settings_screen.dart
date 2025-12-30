import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Settings',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                _buildSectionTitle(context, 'Account'),
                _buildSettingsCard(
                  context,
                  icon: Icons.account_circle,
                  title: 'Profile',
                  subtitle: 'Manage account info',
                  onTap: () => context.go('account-profile'),
                ),
                const SizedBox(height: 12),
                _buildSettingsCard(
                  context,
                  icon: Icons.workspace_premium_outlined,
                  title: 'Subscription',
                  subtitle: 'Manage your plan',
                  onTap: () => context.go('subscription'),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle(context, 'App Settings'),
                _buildSettingsCard(
                  context,
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Theme & display settings',
                  onTap: () => context.go('preferences'),
                ),
                const SizedBox(height: 12),
                _buildSettingsCard(
                  context,
                  icon: Icons.storage_outlined,
                  title: 'Data & Storage',
                  subtitle: 'Cache & offline data',
                  onTap: () => context.go('data-storage'),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle(context, 'Support'),
                _buildSettingsCard(
                  context,
                  icon: Icons.info_outline,
                  title: 'About & Privacy',
                  subtitle: 'App version, terms & privacy',
                  onTap: () => context.go('privacy-about'),
                ),
                const SizedBox(height: 12),
                _buildSettingsCard(
                  context,
                  icon: Icons.card_giftcard,
                  title: 'Refer a Friend',
                  subtitle: 'Invite friends & earn rewards',
                  onTap: () => context.go('referral'),
                ),
                const SizedBox(height: 32),
                _buildLogoutButton(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      color: theme.cardColor,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () async {
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sign Out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign Out',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          );

          if (shouldLogout == true && context.mounted) {
            await Provider.of<AuthService>(context, listen: false).signOut();
            if (context.mounted) context.go('/auth');
          }
        },
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text('Sign Out',
            style: TextStyle(color: Colors.red, fontSize: 16)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.red.withOpacity(0.1),
        ),
      ),
    );
  }
}
