
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreatorTabView extends StatelessWidget {
  const CreatorTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        children: [
          // 1. Hero Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.grey[900]!, Colors.grey[850]!]
                    : [Colors.white, Colors.grey[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Text(
                  "Turn your content into learning — automatically.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Upload once. SumQuiz turns it into summaries, quizzes, and flashcards your students actually finish.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => context.go('/auth'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 20),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: const Text("Create a Deck (Free)"),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    "See how it works",
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),

          // 2. The Creator Problem
          _buildSection(
            context,
            "The Creator Problem",
            [
              _buildProblemCard(context, "Your students:", [
                "Don’t read long PDFs",
                "Watch videos passively",
                "Say they studied — but fail exams"
              ]),
              _buildProblemCard(context, "Your content:", [
                "Gets skimmed",
                "Doesn’t test understanding",
                "Gives you zero feedback"
              ]),
            ],
          ),

          // 3. The SumQuiz Loop
          _buildSection(
            context,
            "The SumQuiz Loop",
            [
              _buildFeatureCard(
                  context, "1. Upload", "Notes, PDFs, or videos"),
              _buildFeatureCard(context, "2. AI Generates",
                  "Clean summary, Auto quiz, Flashcards"),
              _buildFeatureCard(context, "3. Publish", "Share one link"),
            ],
            footer: "You don’t teach more. Your content does.",
          ),

          // 4. What Creators Get
          _buildSection(
            context,
            "What Creators Get",
            [
              _buildBenefitCard(
                  context, "Zero setup (no course building)"),
              _buildBenefitCard(context, "No teaching sessions"),
              _buildBenefitCard(context, "No grading"),
              _buildBenefitCard(context, "No chasing students"),
              _buildBenefitCard(context, "Engagement metrics"),
              _buildBenefitCard(context, "Guaranteed study flow"),
              _buildBenefitCard(context, "Attribution on every deck"),
              _buildBenefitCard(context, "Shareable links"),
            ],
            subheading: "See what students actually use.",
          ),

          // 5. Student Experience
          _buildSection(
            context,
            "Student Experience",
            [
              _buildFeatureCard(context, "Focused Study", "10-15 minute loops"),
              _buildFeatureCard(context, "Offline Access", "Learn anywhere"),
              _buildFeatureCard(
                  context, "Frictionless", "No sign-up needed"),
            ],
            footer:
                "Your students don’t need motivation. They need structure.",
          ),

          // 6. Who This Is For
          _buildSection(
            context,
            "Who This Is For",
            [
              _buildForCard(context, "Perfect for:", [
                "Exam prep tutors (JAMB, WAEC, SAT, etc.)",
                "Course creators",
                "Study communities",
                "YouTube educators"
              ]),
              _buildForCard(context, "Not for:", [
                "Live class management",
                "Homework grading",
                "Full LMS control"
              ]),
            ],
          ),

          // 7. Social Proof
          _buildSection(
            context,
            "Mechanism Proof",
            [
              _buildFeatureCard(
                  context, "Active Recall", "Built around active recall & spaced repetition"),
              _buildFeatureCard(context, "Exam Focused", "Designed for exam-focused learning"),
              _buildFeatureCard(
                  context, "Short Attention", "Optimized for short attention spans"),
            ],
          ),

          // 8. CTA
          Container(
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
            width: double.infinity,
            color: theme.colorScheme.primary.withOpacity(0.1),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/auth'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 20),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: const Text("Start as a Creator — Free"),
                ),
                const SizedBox(height: 16),
                const Text(
                  "No dashboard setup. No payments. Just publish a deck.",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children,
      {String? subheading, String? footer}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (subheading != null) ...[
            const SizedBox(height: 16),
            Text(
              subheading,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 40),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: children,
          ),
          if (footer != null) ...[
            const SizedBox(height: 40),
            Text(
              footer,
              style:
                  theme.textTheme.headlineSmall?.copyWith(fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProblemCard(
      BuildContext context, String title, List<String> items) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text("• $item", style: theme.textTheme.bodyLarge),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, String title, String description) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 300,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitCard(BuildContext context, String benefit) {
    final theme = Theme.of(context);
    return Chip(
      label: Text(benefit, style: theme.textTheme.titleMedium),
      padding: const EdgeInsets.all(12),
    );
  }

  Widget _buildForCard(
      BuildContext context, String title, List<String> items) {
    return _buildProblemCard(context, title, items);
  }
}
