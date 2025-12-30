import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('About & Privacy', style: theme.textTheme.headlineMedium),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
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
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAboutHeader(theme),
                const SizedBox(height: 24),
                _buildLinksCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutHeader(ThemeData theme) {
    return Column(
      children: [
        const Icon(Icons.info_outline, size: 80, color: Colors.blue),
        const SizedBox(height: 16),
        Text(
          'SumQuiz',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _version,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildLinksCard(ThemeData theme) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      color: theme.cardColor,
      child: Column(
        children: [
          _buildLinkTile(
            theme,
            icon: Icons.shield_outlined,
            title: 'Privacy Policy',
            onTap: () => _launchURL(
                'https://sites.google.com/view/sumquiz-privacy-policy/home'),
          ),
          _buildDivider(),
          _buildLinkTile(
            theme,
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => _launchURL(
                'https://sites.google.com/view/terms-and-conditions-for-sumqu/home'),
          ),
          _buildDivider(),
          _buildLinkTile(
            theme,
            icon: Icons.contact_support_outlined,
            title: 'Support & Contact',
            onTap: () => _launchURL('mailto:sumquiz6@gmail.com'),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile(ThemeData theme,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.bodyLarge),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildDivider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
      );
}
