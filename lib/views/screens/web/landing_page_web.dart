import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/views/widgets/web/beta_access_dialog.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/views/screens/web/creator_tab_view.dart';

class LandingPageWeb extends StatefulWidget {
  const LandingPageWeb({super.key});

  @override
  State<LandingPageWeb> createState() => _LandingPageWebState();
}

class _LandingPageWebState extends State<LandingPageWeb>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  // Section keys for scrolling
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _scrollToFeatures() => _scrollToSection(_featuresKey);
  void _scrollToFAQ() => _scrollToSection(_faqKey);

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildNavLink(String text, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: WebColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WebColors.background,
      body: Column(
        children: [
          _buildNavBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Student Tab
                SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      _buildHeroSection(context),
                      _buildStatsSection(context),
                      _buildFeaturesGrid(context),
                      _buildHowItWorks(context),
                      _buildTestimonials(context),
                      _buildFAQ(context),
                      _buildCTASection(context),
                      _buildFooter(context),
                    ],
                  ),
                ),
                // Creator Tab
                const CreatorTabView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: WebColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 1100;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: WebColors.HeroGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: WebColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/sumquiz_logo.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'SumQuiz',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: WebColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                // Navigation Links
                const SizedBox(width: 20),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isNarrow) ...[
                          _buildNavLink('Features', _scrollToFeatures),
                          const SizedBox(width: 16),
                          _buildNavLink('How It Works',
                              () => _scrollToSection(_featuresKey)),
                          const SizedBox(width: 16),
                          _buildNavLink('FAQ', _scrollToFAQ),
                          const SizedBox(width: 24),
                        ],
                        // Tab switcher
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: WebColors.backgroundAlt,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: WebColors.primary.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            labelColor: WebColors.primary,
                            unselectedLabelColor: WebColors.textSecondary,
                            labelStyle:
                                const TextStyle(fontWeight: FontWeight.w600),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'Student'),
                              Tab(text: 'Creator'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        TextButton(
                          onPressed: () => context.go('/auth'),
                          style: TextButton.styleFrom(
                            foregroundColor: WebColors.textSecondary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          child: const Text('Log in'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => context.go('/auth'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WebColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Get Started',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            WebColors.primary,
            WebColors.primary.withOpacity(0.8),
            WebColors.accent.withOpacity(0.6),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              // Left Content
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: WebColors.primary.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed, color: WebColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Study 3x Faster',
                            style: TextStyle(
                              color: WebColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
                    const SizedBox(height: 24),
                    Text(
                      'Master Anything with AI-Powered Learning',
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -1,
                        foreground: Paint()..shader = WebColors.HeroGradient.createShader(
                          Rect.fromLTWH(0, 0, 1200, 100),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 600.ms)
                        .slideX(begin: -0.2),
                    const SizedBox(height: 24),
                    Text(
                      'Transform any content into interactive flashcards, quizzes, and summaries. Retain knowledge 3x longer with spaced repetition and daily missions.',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.6,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 600.ms)
                        .slideX(begin: -0.2),
                    const SizedBox(height: 48),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildPrimaryButton(context, 'Start Learning Free',
                            () => context.go('/auth')),
                        _buildSecondaryButton(
                            context,
                            'Get Mobile App Early Access',
                            _showBetaAccessDialog),
                      ],
                    ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        _buildTrustBadge(Icons.auto_graph, '10k+ Active Users'),
                        _buildTrustBadge(Icons.school, '95% Retention Rate'),
                        _buildTrustBadge(Icons.timer, '3x Faster Learning'),
                      ],
                    ).animate().fadeIn(delay: 800.ms),
                  ],
                ),
              ),
              const SizedBox(width: 60),
              // Right Image
              Expanded(
                flex: 1,
                child: Container(
                  height: 500,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: WebColors.primary.withOpacity(0.3),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/images/web/hero_illustration.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 800.ms)
                    .scale(begin: const Offset(0.9, 0.9)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(
      BuildContext context, String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: WebColors.primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      child: Text(text),
    ).animate().scale(delay: 100.ms);
  }

  Widget _buildSecondaryButton(
      BuildContext context, String text, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      child: Text(text),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            WebColors.backgroundAlt,
          ],
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'PROVEN RESULTS',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Join thousands of students achieving better results',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('10,000+', 'Active Users', Icons.people),
                  _buildStatDivider(),
                  _buildStatItem('95%', 'Retention Rate', Icons.auto_graph),
                  _buildStatDivider(),
                  _buildStatItem('3x', 'Faster Learning', Icons.speed),
                  _buildStatDivider(),
                  _buildStatItem('4.9/5', 'User Rating', Icons.star),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WebColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: WebColors.primary, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: WebColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: WebColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 60,
      width: 1,
      color: WebColors.border,
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    return Container(
      key: _featuresKey,
      padding: const EdgeInsets.symmetric(vertical: 80),
      color: Colors.white,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'POWERFUL FEATURES',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Everything you need to learn smarter',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 48),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 1.2,
                children: [
                  _buildFeatureCard(
                    'AI-Powered Content',
                    'Transform any text, PDF, or video into interactive learning materials',
                    Icons.auto_awesome,
                    WebColors.primary,
                  ),
                  _buildFeatureCard(
                    'Spaced Repetition',
                    'Never forget what you learn with scientifically-proven review scheduling',
                    Icons.schedule,
                    WebColors.secondary,
                  ),
                  _buildFeatureCard(
                    'Daily Missions',
                    'Build consistent learning habits with personalized daily challenges',
                    Icons.flag,
                    WebColors.accent,
                  ),
                  _buildFeatureCard(
                    'Progress Tracking',
                    'Visualize your learning journey with detailed analytics and insights',
                    Icons.show_chart,
                    WebColors.primary,
                  ),
                  _buildFeatureCard(
                    'Offline Access',
                    'Study anywhere, anytime with full offline functionality',
                    Icons.offline_bolt,
                    WebColors.secondary,
                  ),
                  _buildFeatureCard(
                    'Collaborative Learning',
                    'Share decks, compete with friends, and learn together',
                    Icons.group,
                    WebColors.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: WebColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: WebColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildHowItWorks(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            WebColors.backgroundAlt,
            Colors.white,
          ],
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'HOW IT WORKS',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Start learning in minutes',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStepCard(1, 'Import Content',
                      'Paste text, upload PDFs, or link videos'),
                  _buildStepArrow(),
                  _buildStepCard(2, 'AI Processing',
                      'Our AI transforms content into learning materials'),
                  _buildStepArrow(),
                  _buildStepCard(3, 'Start Learning',
                      'Review flashcards, take quizzes, and track progress'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(int number, String title, String description) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: WebColors.HeroGradient,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: WebColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: WebColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildStepArrow() {
    return Icon(
      Icons.arrow_forward,
      color: WebColors.textTertiary,
      size: 32,
    );
  }

  Widget _buildTestimonials(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      color: Colors.white,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'SUCCESS STORIES',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'What our users say',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 48),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 1.1,
                children: [
                  _buildTestimonialCard(
                    'SumQuiz helped me ace my medical boards! The spaced repetition system is a game-changer.',
                    'Dr. Sarah Chen',
                    'Medical Student, Stanford',
                    'assets/images/web/avatar_1.png',
                  ),
                  _buildTestimonialCard(
                    'I went from struggling with chemistry to getting straight A\'s. The AI-generated quizzes are perfect for my learning style.',
                    'Mike Rodriguez',
                    'Chemistry Major, MIT',
                    'assets/images/web/avatar_2.png',
                  ),
                  _buildTestimonialCard(
                    'As a teacher, I love how SumQuiz makes complex topics digestible. My students\' test scores improved by 25%.',
                    'Prof. Jennifer Lee',
                    'University of Oxford',
                    'assets/images/web/avatar_3.png',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestimonialCard(
      String quote, String name, String role, String avatarPath) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: WebColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(avatarPath, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: WebColors.textPrimary,
                    ),
                  ),
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 14,
                      color: WebColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            quote,
            style: TextStyle(
              fontSize: 14,
              color: WebColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 16),
              Icon(Icons.star, color: Colors.amber, size: 16),
              Icon(Icons.star, color: Colors.amber, size: 16),
              Icon(Icons.star, color: Colors.amber, size: 16),
              Icon(Icons.star, color: Colors.amber, size: 16),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildFAQ(BuildContext context) {
    return Container(
      key: _faqKey,
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            WebColors.backgroundAlt,
          ],
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Text(
                'FREQUENTLY ASKED QUESTIONS',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Everything you need to know',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 48),
              _buildFAQItem(
                'How does SumQuiz help me learn faster?',
                'Our AI analyzes your learning patterns and creates personalized content that adapts to your pace. Combined with spaced repetition, you retain information 3x longer than traditional methods.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'Is there a free version?',
                'Yes! Our free plan includes basic features like flashcard creation and simple quizzes. Upgrade to unlock advanced AI features, offline access, and unlimited content generation.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'Can I use SumQuiz for any subject?',
                'Absolutely! SumQuiz works with any text-based content - from academic papers to YouTube transcripts. Our AI adapts to different subjects and complexity levels.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'How does the spaced repetition system work?',
                'Based on the scientifically-proven forgetting curve, our system schedules reviews at optimal intervals. You\'ll see content just before you\'re about to forget it, maximizing retention efficiency.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: WebColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            answer,
            style: TextStyle(
              fontSize: 16,
              color: WebColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        gradient: WebColors.HeroGradient,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Colors.white],
                ).createShader(bounds),
                child: Text(
                  'Ready to Learn Smarter?',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Join thousands of students who are learning 3x faster with SumQuiz. Start your free trial today.',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPrimaryButton(
                      context, 'Start Free Trial', () => context.go('/auth')),
                  const SizedBox(width: 16),
                  _buildSecondaryButton(context, 'Get Mobile App Early Access',
                      _showBetaAccessDialog),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'No credit card required • 14-day free trial • Cancel anytime',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      color: WebColors.textPrimary,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: WebColors.HeroGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Image.asset(
                              'assets/images/sumquiz_logo.png',
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'SumQuiz',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AI-powered learning for the modern student.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildFooterColumn('Product', [
                        'Features',
                        'Pricing',
                        'Use Cases',
                        'Integrations',
                      ]),
                      const SizedBox(width: 60),
                      _buildFooterColumn('Resources', [
                        'Blog',
                        'Tutorials',
                        'Help Center',
                        'API Docs',
                      ]),
                      const SizedBox(width: 60),
                      _buildFooterColumn('Company', [
                        'About',
                        'Careers',
                        'Contact',
                        'Partners',
                      ]),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Container(
                height: 1,
                color: Colors.white.withOpacity(0.1),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '© 2026 SumQuiz. All rights reserved.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.language,
                            color: Colors.white.withOpacity(0.7)),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.facebook,
                            color: Colors.white.withOpacity(0.7)),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.link,
                            color: Colors.white.withOpacity(0.7)),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterColumn(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                item,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            )),
      ],
    );
  }

  void _showBetaAccessDialog() {
    showDialog(
      context: context,
      builder: (context) => const BetaAccessDialog(),
    );
  }
}
