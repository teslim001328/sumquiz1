import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) context.go('/auth');
  }

  void _navigateToNextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: const [
                  OnboardingPage(
                    title: 'From Lecture to Legend',
                    subtitle:
                        'Transform raw notes into powerful summaries and quizzes instantly.',
                    imagePath: 'assets/images/onboarding_learn.svg',
                    highlightColor: Color(0xFF1A237E), // Deep Indigo
                  ),
                  OnboardingPage(
                    title: 'Your Knowledge, Supercharged',
                    subtitle:
                        'Generate flashcards, track momentum, and conquer any subject.',
                    imagePath: 'assets/images/onboarding_notes.svg',
                    highlightColor: Color(0xFF00695C), // Teal
                  ),
                  OnboardingPage(
                    title: 'Master It All',
                    subtitle:
                        'Start for free today. Upgrade your study strategy forever.',
                    imagePath: 'assets/images/onboarding_rocket.svg',
                    highlightColor: Color(0xFFC62828), // Red
                  ),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) => _buildDot(index)),
          ),
          const SizedBox(height: 56),

          // Adaptive Button Area
          SizedBox(
            height: 120, // Fixed height to prevent layout jumps
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _currentPage == 2
                  ? _buildGetStartedButtons()
                  : _buildNextButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGetStartedButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      key: const ValueKey('getStartedButtons'),
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _finishOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E), // Brand Color
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF1A237E).withOpacity(0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle:
                  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            child: const Text('Get Started Free'),
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _finishOnboarding,
          child: Text(
            'Already have an account? Sign In',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
      ],
    );
  }

  Widget _buildNextButton() {
    return Align(
        alignment: Alignment.bottomCenter,
        key: const ValueKey('nextButton'),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _navigateToNextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[100],
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300)),
              textStyle:
                  GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            child: const Text('Next'),
          ),
        ));
  }

  Widget _buildDot(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      height: 8,
      width: isActive ? 32 : 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1A237E) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color highlightColor;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration with Animation
          Expanded(
            flex: 5,
            child: Center(
              child: SvgPicture.asset(
                imagePath,
                width: double.infinity,
                placeholderBuilder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              ).animate(target: 1).scale(
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                  begin: const Offset(0.9, 0.9)),
            ),
          ),

          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 100.ms)
                    .slideY(begin: 0.2, end: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
