
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
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

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0F172A);
    const primaryColor = Color(0xFF6366F1);
    const secondaryColor = Color(0xFFEC4899);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.2),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: secondaryColor.withOpacity(0.15),
                ),
              ),
            ),
          ),
          Column(
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
                          _buildFeaturesGrid(context),
                          _buildHowItWorks(context),
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
        ],
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/sumquiz_logo.png',
                      height: 32,
                      width: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text("SumQuiz",
                      style: textTheme.headlineSmall?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
              SizedBox(
                width: 300,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(text: "For Students"),
                    Tab(text: "For Creators"),
                  ],
                ),
              ),
              Row(
                children: [
                  TextButton(
                      onPressed: () => context.go('/auth'),
                      child: Text("Log In",
                          style: textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600))),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/auth'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text("Get Started",
                        style: textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildHeroSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 1200),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3)),
                  ),
                  child: Text("🚀 #1 AI Study Tool for 2026",
                      style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF818CF8),
                          fontWeight: FontWeight.w600)),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 24),
                Text(
                  "Crush Your Exams with\nAI Superpowers.",
                  style: textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                const SizedBox(height: 24),
                Text(
                  "Turn any text, PDF, video, or link into summaries, quizzes, and flashcards in seconds. Stop reading. Start mastering.",
                  style: textTheme.bodyLarge?.copyWith(
                      fontSize: 18, color: Colors.white70, height: 1.6),
                ).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 48),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => context.go('/auth'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 20),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 10,
                        shadowColor:
                            const Color(0xFF6366F1).withOpacity(0.4),
                      ),
                      child: Row(
                        children: [
                          Text("Start Learning for Free",
                              style: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 20, color: Colors.white),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 20),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_outline,
                              size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text("Watch Demo",
                              style: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
              ],
            ),
          ),
          Expanded(flex: 1, child: Container()),
          Expanded(
            flex: 5,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(-0.1)
                ..rotateZ(-0.05),
              child: Container(
                height: 500,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        blurRadius: 50,
                        offset: const Offset(-20, 20)),
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: Container(
                          color: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Row(
                                children: List.generate(
                                    3,
                                    (i) => Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white
                                                .withOpacity(0.2)))),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(Icons.auto_awesome_motion,
                            size: 120,
                            color: Colors.white.withOpacity(0.05)),
                      ),
                      Positioned(
                        top: 80,
                        left: 30,
                        right: 30,
                        bottom: 30,
                        child: Column(
                          children: [
                            Container(
                                height: 200,
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16))),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                    child: Container(
                                        height: 120,
                                        decoration: BoxDecoration(
                                            color: Colors.white
                                                .withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(16)))),
                                const SizedBox(width: 20),
                                Expanded(
                                    child: Container(
                                        height: 120,
                                        decoration: BoxDecoration(
                                            color: Colors.white
                                                .withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(16)))),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 600.ms)
              .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final features = [
      {
        'icon': Icons.bolt,
        'color': Colors.amber,
        'title': 'Instant Summaries',
        'desc': 'Condense 50-page PDFs into 1-page summaries in seconds.'
      },
      {
        'icon': Icons.psychology,
        'color': Colors.pink,
        'title': 'Smart Quizzes',
        'desc':
            'Generate multiple-choice or short-answer questions to test your knowledge.'
      },
      {
        'icon': Icons.school,
        'color': Colors.blue,
        'title': 'Flashcards',
        'desc':
            'Master concepts with spaced repetition flashcards automatically created for you.'
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              Text("The Ultimate Exam Tech Stack",
                  style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Text("Everything you need to study smarter, not harder.",
                  style: textTheme.titleLarge
                      ?.copyWith(fontSize: 18, color: Colors.white60)),
              const SizedBox(height: 60),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: features.map((feature) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (feature['color'] as Color)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(feature['icon'] as IconData,
                                color: feature['color'] as Color, size: 32),
                          ),
                          const SizedBox(height: 24),
                          Text(feature['title'] as String,
                              style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 12),
                          Text(feature['desc'] as String,
                              style: textTheme.bodyLarge?.copyWith(
                                  color: Colors.white60, height: 1.5)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorks(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      color: Colors.black.withOpacity(0.2),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              Text("How It Works",
                  style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 60),
              _buildStep(
                number: "01",
                title: "Import Content",
                desc: "Paste text, upload a PDF, or drop a YouTube link.",
                alignRight: false,
                textTheme: textTheme,
              ),
              _buildStep(
                number: "02",
                title: "AI Analysis",
                desc:
                    "Our advanced AI extracts key concepts and generates study materials.",
                alignRight: true,
                textTheme: textTheme,
              ),
              _buildStep(
                number: "03",
                title: "Ace the Exam",
                desc: "Review summaries, take quizzes, and master flashcards.",
                alignRight: false,
                textTheme: textTheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
      {required String number,
      required String title,
      required String desc,
      required bool alignRight,
      required TextTheme textTheme}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 60),
      child: Row(
        textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: alignRight
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(number,
                    style: textTheme.displayLarge?.copyWith(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.05))),
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Column(
                    crossAxisAlignment: alignRight
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(desc,
                          style: textTheme.titleMedium
                              ?.copyWith(color: Colors.white60),
                          textAlign:
                              alignRight ? TextAlign.right : TextAlign.left),
                    ],
                  ),
                )
              ],
            ),
          ),
          Expanded(child: Container()),
        ],
      ),
    );
  }

  Widget _buildCTASection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 40),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.all(60),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                )
              ]),
          child: Column(
            children: [
              Text(
                "Ready to revolutionize your study routine?",
                style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                "Join thousands of students acing their exams with SumQuiz.",
                style: textTheme.titleLarge
                    ?.copyWith(color: Colors.white.withOpacity(0.9)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => context.go('/auth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4F46E5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Get Started Now - It's Free"),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildFooter(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Center(
        child: Text(
          "© 2024 SumQuiz. Built for the future of learning.",
          style: textTheme.bodyMedium?.copyWith(color: Colors.white30),
        ),
      ),
    );
  }
}
