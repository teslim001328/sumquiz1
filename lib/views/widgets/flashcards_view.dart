import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:developer' as developer;
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/flashcard.dart';

class FlashcardsView extends StatefulWidget {
  final String title;
  final List<Flashcard> flashcards;
  final Function(int index, bool knewIt) onReview;
  final VoidCallback onFinish;
  final String? creatorName;

  const FlashcardsView({
    super.key,
    required this.title,
    required this.flashcards,
    required this.onReview,
    required this.onFinish,
    this.creatorName,
  });

  @override
  State<FlashcardsView> createState() => _FlashcardsViewState();
}

class _FlashcardsViewState extends State<FlashcardsView> {
  final CardSwiperController _swiperController = CardSwiperController();
  int _currentIndex = 0;

  bool _onSwipe(
      int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    if (currentIndex == null) {
      widget.onFinish();
    } else {
      setState(() {
        _currentIndex = currentIndex;
      });
    }
    return true;
  }

  void _handleReview(int index, bool knewIt) {
    widget.onReview(index, knewIt);
    _swiperController.swipe(CardSwiperDirection.right);
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    developer.log('FlashcardsView build: ${widget.flashcards.length} cards',
        name: 'flashcards.view');
    if (widget.flashcards.isEmpty) {
      return Center(
          child: Text("No flashcards available.",
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurface)));
    }

    // Progress bar value
    double progress = (_currentIndex + 1) / widget.flashcards.length;

    return SafeArea(
      child: Column(
        children: [
          // Header with Progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              children: [
                Text(widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onPrimary)),
                if (widget.creatorName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Created by ${widget.creatorName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: theme.colorScheme.onPrimary
                              .withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.secondary),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_currentIndex + 1}/${widget.flashcards.length}',
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onPrimary
                              .withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Card Swiper
          Expanded(
            child: CardSwiper(
              controller: _swiperController,
              cardsCount: widget.flashcards.length,
              onSwipe: _onSwipe,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              cardBuilder:
                  (context, index, percentThresholdX, percentThresholdY) {
                final card = widget.flashcards[index];
                return FlipCard(
                  front: _buildCardSide(card.question,
                      isFront: true, theme: theme),
                  back: _buildCardSide(card.answer,
                      isFront: false, cardIndex: index, theme: theme),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSide(String text,
      {required bool isFront, int? cardIndex, required ThemeData theme}) {
    return _buildGlassCard(
      theme: theme,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header content (e.g., "Question" label)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              isFront ? "QUESTION" : "ANSWER",
              style: theme.textTheme.labelMedium?.copyWith(
                color: isFront
                    ? theme.colorScheme.primary.withValues(alpha: 0.8)
                    : theme.colorScheme.tertiary.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),

          // Footer / Actions
          if (!isFront)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildGlassButton(
                    label: "Still Learning",
                    icon: Icons.refresh_rounded,
                    color: Colors.orange,
                    onPressed: () => _handleReview(cardIndex!, false),
                    theme: theme,
                  ),
                  _buildGlassButton(
                    label: "Got It",
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    onPressed: () => _handleReview(cardIndex!, true),
                    theme: theme,
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined,
                      size: 20,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 8),
                  Text(
                    "Tap to Flip",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ).animate(onPlay: (c) => c.repeat(reverse: true)).fade().scale(),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, required ThemeData theme}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: theme.cardColor.withValues(alpha: 0.9), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
