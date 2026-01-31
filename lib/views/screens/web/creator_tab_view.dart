import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/theme/web_theme.dart';

class CreatorTabView extends StatelessWidget {
  const CreatorTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroSection(context),
          _buildVisualStats(context),
          _buildProcessSection(context),
          _buildFeaturesSection(context),
          _buildTestimonials(context),
          _buildFAQ(context),
          _buildCTASection(context),
          _buildFooter(context),
        ],
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
            WebColors.background,
            WebColors.primary.withOpacity(0.05),
            const Color(0xFFF3E8FF), // Light purple for creator vibe
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
                            color: WebColors.primary.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.monetization_on,
                              color: WebColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Earn 70% Revenue Share',
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
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                      ).createShader(bounds),
                      child: Text(
                        'Monetize Your Knowledge',
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -1,
                          color: Colors.white,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 600.ms)
                        .slideX(begin: -0.2),
                    const SizedBox(height: 24),
                    Text(
                      'Create once, earn forever. Transform your expertise into interactive study decks and reach thousands of students globally.',
                      style: TextStyle(
                        fontSize: 20,
                        color: WebColors.textSecondary,
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
                        _buildPrimaryButton(context, 'Start Creating Now',
                            () => context.go('/create')),
                        _buildSecondaryButton(context, 'View Dashboard',
                            () => context.go('/dashboard')),
                      ],
                    ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        _buildTrustBadge(Icons.auto_graph, 'Passive Income'),
                        _buildTrustBadge(Icons.public, 'Global Reach'),
                        _buildTrustBadge(Icons.shield, 'Secure Payouts'),
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
                        color: WebColors.primary.withOpacity(0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/images/web/creator_hero.png',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: WebColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: WebColors.textPrimary,
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
        backgroundColor: WebColors.primary,
        foregroundColor: Colors.white,
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
        foregroundColor: WebColors.primary,
        side: BorderSide(color: WebColors.primary),
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

  Widget _buildVisualStats(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      color: Colors.white,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                  '\$2.5k+', 'Avg. Creator Earnings', Icons.payments),
              _buildDivider(),
              _buildStatItem('500+', 'Active Creators', Icons.people),
              _buildDivider(),
              _buildStatItem('24h', 'Payout Processing', Icons.timer),
              _buildDivider(),
              _buildStatItem('70%', 'Revenue Share', Icons.pie_chart),
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

  Widget _buildDivider() {
    return Container(
      height: 60,
      width: 1,
      color: WebColors.border,
    );
  }

  Widget _buildProcessSection(BuildContext context) {
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
                'SIMPLE PROCESS',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Create and earn in 3 easy steps',
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
                  _buildStepCard(1, 'Create Content',
                      'Transform your expertise into interactive study materials'),
                  _buildStepArrow(),
                  _buildStepCard(2, 'Publish & Share',
                      'Make your decks available to thousands of global learners'),
                  _buildStepArrow(),
                  _buildStepCard(3, 'Earn Revenue',
                      'Get paid 70% of every purchase, with 24-hour payouts'),
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
              gradient: LinearGradient(
                colors: [WebColors.primary, const Color(0xFF9333EA)],
              ),
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

  Widget _buildFeaturesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      color: Colors.white,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'CREATOR TOOLS',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Everything you need to succeed',
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
                    'AI Content Creation',
                    'Generate high-quality study materials from your expertise in seconds',
                    Icons.auto_awesome,
                    WebColors.primary,
                  ),
                  _buildFeatureCard(
                    'Analytics Dashboard',
                    'Track performance, revenue, and student engagement in real-time',
                    Icons.show_chart,
                    WebColors.secondary,
                  ),
                  _buildFeatureCard(
                    'Global Marketplace',
                    'Reach learners worldwide with automatic translation and localization',
                    Icons.public,
                    WebColors.accent,
                  ),
                  _buildFeatureCard(
                    'Flexible Pricing',
                    'Set your own prices and offer discounts or subscriptions',
                    Icons.price_change,
                    WebColors.primary,
                  ),
                  _buildFeatureCard(
                    'Community Support',
                    'Join our creator community and get expert support',
                    Icons.group,
                    WebColors.secondary,
                  ),
                  _buildFeatureCard(
                    'Marketing Tools',
                    'Built-in promotion tools to help you grow your audience',
                    Icons.trending_up,
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
        color: WebColors.backgroundAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
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

  Widget _buildTestimonials(BuildContext context) {
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
                'CREATOR SUCCESS',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hear from our top creators',
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
                crossAxisCount: 2,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 1.4,
                children: [
                  _buildCreatorTestimonial(
                    'I made \$5,000 in my first month! SumQuiz\'s creator tools are incredible.',
                    'Alex Thompson',
                    'Computer Science Professor',
                    '\$5,000',
                    'First Month Earnings',
                  ),
                  _buildCreatorTestimonial(
                    'The 70% revenue share is amazing. I\'ve earned over \$15,000 this year.',
                    'Dr. Maria Rodriguez',
                    'Medical Education Specialist',
                    '\$15,000+',
                    'Annual Earnings',
                  ),
                  _buildCreatorTestimonial(
                    'Creating content is so easy. I spend 2 hours a week and earn passive income.',
                    'James Wilson',
                    'Business Consultant',
                    '2 hrs/week',
                    'Time Investment',
                  ),
                  _buildCreatorTestimonial(
                    'The global reach is incredible. I have students from 20+ countries.',
                    'Sarah Kim',
                    'Language Instructor',
                    '20+ countries',
                    'Global Reach',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorTestimonial(
      String quote, String name, String role, String stat, String statLabel) {
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: WebColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    name[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WebColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_money, color: WebColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  stat,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: WebColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  statLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: WebColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildFAQ(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      color: Colors.white,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Text(
                'CREATOR FAQ',
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
                'How much can I earn as a creator?',
                'Earnings vary based on content quality and demand. Top creators earn \$2,000-\$10,000+ monthly. We take only 30% platform fee, you keep 70% of all sales.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'What type of content performs best?',
                'High-demand subjects like programming, medicine, business, and language learning perform best. Interactive content with quizzes and flashcards gets higher engagement.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'How do I get paid?',
                'We process payments within 24 hours via PayPal, Stripe, or bank transfer. You can set your preferred payment method in your creator dashboard.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'Do I need teaching experience?',
                'Not at all! Anyone with expertise in a subject can create valuable content. Our AI tools help you structure and format your knowledge effectively.',
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
        color: WebColors.backgroundAlt,
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
        gradient: LinearGradient(
          colors: [WebColors.primary, const Color(0xFF9333EA)],
        ),
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
                  'Ready to Start Earning?',
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
                'Join our community of creators and start monetizing your knowledge today. No experience required.',
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
                      context, 'Become a Creator', () => context.go('/create')),
                  const SizedBox(width: 16),
                  _buildSecondaryButton(context, 'View Creator Hub',
                      () => context.go('/dashboard')),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Free to join • No upfront costs • Start earning immediately',
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
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'SumQuiz Creator',
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
                        'Empowering creators to monetize knowledge.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildFooterColumn('For Creators', [
                        'Creator Dashboard',
                        'Earnings Calculator',
                        'Content Guidelines',
                        'Creator Community',
                      ]),
                      const SizedBox(width: 60),
                      _buildFooterColumn('Resources', [
                        'Creator Handbook',
                        'Best Practices',
                        'Marketing Tips',
                        'Success Stories',
                      ]),
                      const SizedBox(width: 60),
                      _buildFooterColumn('Support', [
                        'Creator Support',
                        'Technical Help',
                        'Payment Issues',
                        'Content Review',
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
                    '© 2024 SumQuiz Creator Program. All rights reserved.',
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
}
