import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _toggleCreatorMode(
      BuildContext context, UserModel? user, bool value) async {
    if (user == null) return;

    if (value) {
      // Confirm enabling
      final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Become a Creator?'),
                content: const Text(
                    'This will enable "Publish" buttons on your content. You can share your decks with anyone!'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Enable')),
                ],
              ));
      if (confirm != true) return;
    }

    try {
      await FirestoreService().updateUserRole(
          user.uid, value ? UserRole.creator : UserRole.student);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                value ? 'Creator Tools Enabled!' : 'Creator Tools Disabled')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.watch<UserModel?>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A237E))),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: isDark ? Colors.white : const Color(0xFF1A237E)),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Animated Gradient Background
          Animate(
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: [
              CustomEffect(
                duration: 6.seconds,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF0F172A),
                                Color.lerp(const Color(0xFF0F172A),
                                    const Color(0xFF1E293B), value)!
                              ]
                            : [
                                const Color(0xFFF3F4F6),
                                Color.lerp(const Color(0xFFE8EAF6),
                                    const Color(0xFFC5CAE9), value)!
                              ],
                      ),
                    ),
                    child: child,
                  );
                },
              )
            ],
            child: Container(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      _buildSectionTitle('Account', theme)
                          .animate()
                          .fadeIn(delay: 100.ms),
                      _buildSettingsCard(
                        context,
                        icon: Icons.account_circle,
                        title: 'Profile',
                        subtitle: 'Manage account info',
                        onTap: () => context.push('/settings/account-profile'),
                        delay: 150.ms,
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsCard(
                        context,
                        icon: Icons.workspace_premium_outlined,
                        title: 'Subscription',
                        subtitle: 'Manage your plan',
                        onTap: () => context.push('/settings/subscription'),
                        delay: 200.ms,
                        theme: theme,
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('App Settings', theme)
                          .animate()
                          .fadeIn(delay: 250.ms),
                      _buildSettingsCard(
                        context,
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        subtitle: 'Theme & display settings',
                        onTap: () => context.push('/settings/preferences'),
                        delay: 300.ms,
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsCard(
                        context,
                        icon: Icons.storage_outlined,
                        title: 'Data & Storage',
                        subtitle: 'Cache & offline data',
                        onTap: () => context.push('/settings/data-storage'),
                        delay: 350.ms,
                        theme: theme,
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('Creator Studio', theme)
                          .animate()
                          .fadeIn(delay: 330.ms),
                      Consumer<UserModel?>(
                        builder: (context, user, _) {
                          final isCreator = user?.role == UserRole.creator;
                          return _buildToggleCard(
                            context,
                            icon: Icons.create,
                            title: 'Enable Creator Tools',
                            subtitle: 'Publish and share decks',
                            value: isCreator,
                            onChanged: (val) =>
                                _toggleCreatorMode(context, user, val),
                            delay: 350.ms,
                            theme: theme,
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      _buildSectionTitle('Support', theme)
                          .animate()
                          .fadeIn(delay: 350.ms),
                      _buildSettingsCard(
                        context,
                        icon: Icons.info_outline,
                        title: 'About & Privacy',
                        subtitle: 'App version, terms & privacy',
                        onTap: () => context.push('/settings/privacy-about'),
                        delay: 450.ms,
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsCard(
                        context,
                        icon: Icons.card_giftcard,
                        title: 'Refer a Friend',
                        subtitle: 'Invite friends & earn rewards',
                        onTap: () => context.push('/settings/referral'),
                        delay: 500.ms,
                        theme: theme,
                      ),
                      if (user?.role == UserRole.creator) ...[
                        _buildSettingsCard(
                          context,
                          icon: Icons.person_pin,
                          title: 'Creator Profile',
                          subtitle: 'Edit your public presence',
                          onTap: () => context.push('/edit_profile'),
                          delay: 800.ms,
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 48),
                      _buildLogoutButton(context, theme)
                          .animate()
                          .fadeIn(delay: 550.ms)
                          .slideY(begin: 0.2),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
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
    required Duration delay,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Animate(
      effects: [FadeEffect(delay: delay), SlideEffect(delay: delay)],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: isDark ? 0.5 : 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon,
                          color: theme.colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6))),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 16, color: theme.disabledColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: isDark ? 0.5 : 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextButton.icon(
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: theme.dialogBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  title: Text('Sign Out',
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold)),
                  content: Text('Are you sure you want to sign out?',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.8))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign Out',
                            style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );

              if (shouldLogout == true && context.mounted) {
                await Provider.of<AuthService>(context, listen: false)
                    .signOut();
                if (context.mounted) context.go('/auth');
              }
            },
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: Text('Sign Out',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required Duration delay,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: theme.colorScheme.primary,
                ),
              ],
            ),
          )
              .animate(delay: delay)
              .fadeIn(curve: Curves.easeOut)
              .slideX(begin: 0.2, curve: Curves.easeOut),
        ),
      ),
    );
  }
}
