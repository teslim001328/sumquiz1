import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/providers/theme_provider.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  int _fontSizeIndex = 1;
  bool _notificationsEnabled = true;
  bool _hapticFeedbackEnabled = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Preferences',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionHeader(theme, 'Appearance'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                ),
                color: theme.cardColor,
                child: Column(
                  children: [
                    _buildDarkModeTile(themeProvider, theme),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                          height: 1,
                          color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildFontSizeSelector(themeProvider, theme),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(theme, 'Interaction'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                ),
                color: theme.cardColor,
                child: Column(
                  children: [
                    _buildToggleOption(
                      context,
                      title: 'Notifications',
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                          height: 1,
                          color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    _buildToggleOption(
                      context,
                      title: 'Haptic Feedback',
                      value: _hapticFeedbackEnabled,
                      onChanged: (value) {
                        setState(() {
                          _hapticFeedbackEnabled = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDarkModeTile(ThemeProvider themeProvider, ThemeData theme) {
    return SwitchListTile(
      title: Text('Dark Mode', style: theme.textTheme.bodyLarge),
      secondary:
          Icon(Icons.dark_mode_outlined, color: theme.colorScheme.primary),
      value: themeProvider.themeMode == ThemeMode.dark,
      onChanged: (value) => themeProvider.toggleTheme(),
      activeColor: theme.colorScheme.primary,
    );
  }

  Widget _buildFontSizeSelector(ThemeProvider themeProvider, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_size, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Text('Font Size', style: theme.textTheme.bodyLarge),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _buildFontSizeOption(themeProvider, 0, 'Small', 0.8, theme),
              _buildFontSizeOption(themeProvider, 1, 'Medium', 1.0, theme),
              _buildFontSizeOption(themeProvider, 2, 'Large', 1.2, theme),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildFontSizeOption(ThemeProvider themeProvider, int index,
      String text, double scale, ThemeData theme) {
    final isSelected = _fontSizeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _fontSizeIndex = index;
            themeProvider.setFontScale(scale);
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
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
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return SwitchListTile(
      title: Text(title, style: theme.textTheme.bodyLarge),
      secondary: Icon(
          title == 'Notifications' ? Icons.notifications_none : Icons.vibration,
          color: theme.colorScheme.primary),
      value: value,
      onChanged: onChanged,
      activeColor: theme.colorScheme.primary,
    );
  }
}
