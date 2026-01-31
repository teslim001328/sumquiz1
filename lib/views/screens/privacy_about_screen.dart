import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PrivacyAboutScreen extends StatefulWidget {
  const PrivacyAboutScreen({super.key});

  @override
  State<PrivacyAboutScreen> createState() => _PrivacyAboutScreenState();
}

class _PrivacyAboutScreenState extends State<PrivacyAboutScreen> {
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v${info.version}';
    });
  }

  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);

      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'About & Privacy',
          style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.primary),
          onPressed: () => context.pop(),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAboutHeader(theme)
                          .animate()
                          .fadeIn(delay: 100.ms)
                          .slideY(begin: 0.1),
                      const SizedBox(height: 32),
                      _buildLinksCard(theme)
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.1),
                      const SizedBox(height: 24),
                      Text(
                        '© 2026 SumQuiz. All rights reserved.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                      ).animate().fadeIn(delay: 400.ms),
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

  Widget _buildAboutHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                width: 2),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(Icons.info_outline,
              size: 60, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 24),
        Text(
          'SumQuiz',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Text(
            _version,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinksCard(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildLinkTile(
                icon: Icons.shield_outlined,
                title: 'Privacy Policy',
                onTap: () => _launchURL(
                    'https://sites.google.com/view/sumquiz-privacy-policy/home'),
                theme: theme,
              ),
              _buildDivider(theme),
              _buildLinkTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => _launchURL(
                    'https://sites.google.com/view/terms-and-conditions-for-sumqu/home'),
                theme: theme,
              ),
              _buildDivider(theme),
              _buildLinkTile(
                icon: Icons.contact_support_outlined,
                title: 'Support & Contact',
                onTap: () => _launchURL('mailto:sumquiz6@gmail.com'),
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      required ThemeData theme}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title,
            style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500)),
        trailing:
            Icon(Icons.arrow_forward_ios, size: 16, color: theme.disabledColor),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Divider(
            height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),
      );
}
