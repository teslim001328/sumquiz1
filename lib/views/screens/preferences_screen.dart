import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/providers/theme_provider.dart';
import 'package:sumquiz/services/notification_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate current font size index for UI selection
    int fontSizeIndex = 1;
    if (themeProvider.fontScale == 0.8) fontSizeIndex = 0;
    if (themeProvider.fontScale == 1.2) fontSizeIndex = 2;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Preferences',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Animated Background
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
                                theme.colorScheme.surface,
                                Color.lerp(theme.colorScheme.surface,
                                    theme.colorScheme.primaryContainer, value)!,
                              ]
                            : [
                                const Color(0xFFF3F4F6),
                                Color.lerp(const Color(0xFFE8EAF6),
                                    const Color(0xFFC5CAE9), value)!,
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    _buildSectionHeader('Appearance', theme)
                        .animate()
                        .fadeIn()
                        .slideX(),
                    const SizedBox(height: 16),
                    _buildGlassSection(
                      theme: theme,
                      children: [
                        _buildDarkModeTile(themeProvider, theme),
                        _buildDivider(theme),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: _buildFontSizeSelector(
                              themeProvider, fontSizeIndex, theme),
                        ),
                      ],
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Interaction', theme)
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideX(),
                    const SizedBox(height: 16),
                    _buildGlassSection(
                      theme: theme,
                      children: [
                        _buildToggleOption(
                          context,
                          title: 'Notifications',
                          value: themeProvider.notificationsEnabled,
                          icon: Icons.notifications_none,
                          onChanged: (value) async {
                            themeProvider.toggleNotifications(value);
                            // Also update the notification service
                            final notificationService =
                                context.read<NotificationService>();
                            await notificationService
                                .toggleNotifications(value);

                            // Show confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(value
                                    ? 'Notifications enabled'
                                    : 'Notifications disabled'),
                                backgroundColor:
                                    value ? Colors.green : Colors.orange,
                              ),
                            );
                          },
                          theme: theme,
                        ),
                        _buildDivider(theme),
                        _buildToggleOption(
                          context,
                          title: 'Haptic Feedback',
                          value: themeProvider.hapticFeedbackEnabled,
                          icon: Icons.vibration,
                          onChanged: (value) {
                            themeProvider.toggleHapticFeedback(value);
                          },
                          theme: theme,
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Debug', theme)
                        .animate()
                        .fadeIn(delay: 400.ms)
                        .slideX(),
                    const SizedBox(height: 16),
                    _buildGlassSection(
                      theme: theme,
                      children: [

                        ListTile(
                          title: Text('Request Permissions',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface)),
                          subtitle: Text(
                              'Request notification permissions from system',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6))),
                          trailing: Icon(Icons.security,
                              color: theme.colorScheme.primary),
                          onTap: () async {
                            final notificationService =
                                context.read<NotificationService>();
                            await notificationService.requestPermissions();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Permission request sent! Check your system settings.'),
                                backgroundColor: theme.colorScheme.primary,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          },
                        ),
                        _buildDivider(theme),
                        FutureBuilder<bool>(
                          future: context
                              .read<NotificationService>()
                              .areNotificationsEnabled(),
                          builder: (context, snapshot) {
                            final isEnabled = snapshot.data ?? true;
                            return ListTile(
                              title: Text('Notification Status',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface)),
                              subtitle: Text(
                                  isEnabled
                                      ? 'Notifications are currently enabled'
                                      : 'Notifications are currently disabled',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isEnabled
                                          ? Colors.green
                                          : Colors.red)),
                              trailing: Icon(
                                  isEnabled ? Icons.check_circle : Icons.cancel,
                                  color: isEnabled ? Colors.green : Colors.red),
                            );
                          },
                        ),
                      ],
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGlassSection(
      {required List<Widget> children, required ThemeData theme}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: theme.cardColor.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: theme.dividerColor.withValues(alpha: 0.2),
    );
  }

  Widget _buildDarkModeTile(ThemeProvider themeProvider, ThemeData theme) {
    return SwitchListTile(
      title: Text('Dark Mode',
          style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface)),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.dark_mode_outlined,
            color: theme.colorScheme.primary, size: 20),
      ),
      value: themeProvider.themeMode == ThemeMode.dark,
      onChanged: (value) => themeProvider.toggleTheme(),
      activeTrackColor: theme.colorScheme.primary,
      hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  Widget _buildFontSizeSelector(
      ThemeProvider themeProvider, int currentSizeIndex, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.format_size,
                  color: Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 16),
            Text('Font Size',
                style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: theme.disabledColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildFontSizeOption(
                  themeProvider, 0, 'Small', 0.8, currentSizeIndex, theme),
              _buildFontSizeOption(
                  themeProvider, 1, 'Medium', 1.0, currentSizeIndex, theme),
              _buildFontSizeOption(
                  themeProvider, 2, 'Large', 1.2, currentSizeIndex, theme),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildFontSizeOption(ThemeProvider themeProvider, int index,
      String text, double scale, int currentIndex, ThemeData theme) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          themeProvider.setFontScale(scale);
        },
        child: AnimatedContainer(
          duration: 200.ms,
          decoration: BoxDecoration(
            color: isSelected ? theme.cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption(
    BuildContext context, {
    required String title,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    return SwitchListTile(
      title: Text(title,
          style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface)),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: theme.colorScheme.secondary, size: 20),
      ),
      value: value,
      onChanged: onChanged,
      activeTrackColor: theme.colorScheme.secondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}
