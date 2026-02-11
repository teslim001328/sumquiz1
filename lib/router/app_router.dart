import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/editable_content.dart';
import 'package:sumquiz/models/flashcard_set.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/summary_model.dart';
import 'package:sumquiz/models/extraction_result.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/views/screens/auth_screen.dart';
import 'package:sumquiz/views/screens/library_screen.dart';
import 'package:sumquiz/views/screens/progress_screen.dart';
import 'package:sumquiz/views/screens/settings_screen.dart';
import 'package:sumquiz/views/screens/review_screen.dart';
import 'package:sumquiz/views/screens/summary_screen.dart';
import 'package:sumquiz/views/screens/quiz_screen.dart';
import 'package:sumquiz/views/screens/flashcards_screen.dart';
import 'package:sumquiz/views/screens/edit_screen.dart';
import 'package:sumquiz/views/screens/edit_creator_profile_screen.dart';
import 'package:sumquiz/views/screens/creator_dashboard_screen.dart';
import 'package:sumquiz/views/screens/edit_quiz_screen.dart';
import 'package:sumquiz/views/screens/edit_flashcards_screen.dart';
import 'package:sumquiz/views/screens/preferences_screen.dart';
import 'package:sumquiz/views/screens/data_storage_screen.dart';
import 'package:sumquiz/views/screens/subscription_screen.dart';
import 'package:sumquiz/views/screens/privacy_about_screen.dart';
import 'package:sumquiz/views/screens/splash_screen.dart';
import 'package:sumquiz/views/screens/onboarding_screen.dart';
import 'package:sumquiz/views/screens/referral_screen.dart';
import 'package:sumquiz/views/screens/account_profile_screen.dart';
import 'package:sumquiz/views/screens/create_content_screen.dart';
import 'package:sumquiz/views/screens/extraction_view_screen.dart';
import 'package:sumquiz/views/screens/results_view_screen.dart';
import 'package:sumquiz/views/widgets/scaffold_with_nav_bar.dart';
import 'package:sumquiz/views/widgets/responsive_view.dart';
import 'package:sumquiz/views/screens/web/library_screen_web.dart';
import 'package:sumquiz/views/screens/web/create_content_screen_web.dart';
import 'package:sumquiz/views/screens/web/progress_screen_web.dart';
import 'package:sumquiz/views/screens/web/results_view_screen_web.dart';
import 'package:sumquiz/views/screens/web/landing_page_web.dart';
import 'package:sumquiz/views/screens/teacher_landing_screen.dart';
import 'package:sumquiz/views/screens/exam_creation_screen.dart';
import 'package:sumquiz/views/screens/web/review_screen_web.dart';
import 'package:sumquiz/views/screens/web/extraction_view_screen_web.dart';
import 'package:sumquiz/views/screens/public_deck_screen.dart';

// GoRouterRefreshStream class
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Keys for shell branches
final _libraryShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'LibraryShell');
final _reviewShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'ReviewShell');
final _createShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'CreateShell');
final _progressShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'ProgressShell');

GoRouter createAppRouter(AuthService authService) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)
        ? '/landing'
        : '/splash',
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) {
      final user = authService.currentUser;
      final isAuthRoute = state.matchedLocation == '/auth';
      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isLanding = state.matchedLocation == '/landing';

      // Web & Desktop Logic: Bypass Splash and Onboarding completely
      final isDesktop = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS);

      if (kIsWeb || isDesktop) {
        if (state.matchedLocation == '/splash' ||
            state.matchedLocation == '/onboarding') {
          return '/landing';
        }
      }

      if (isSplash || isOnboarding) {
        return null; // Allow splash and onboarding (Mobile only)
      }

      // Redirect unauthenticated users
      if (user == null) {
        // If trying to access root or protected routes, go to Landing
        if (state.matchedLocation == '/' || (!isAuthRoute && !isLanding)) {
          return '/landing';
        }
        return null; // Allow access to auth or landing
      }

      // Redirect authenticated users
      if (isAuthRoute || isLanding || isSplash || isOnboarding) {
        return '/';
      }

      return null;
    },
    routes: <RouteBase>[
      // Top-level routes that should not have the nav bar
      GoRoute(
        path: '/landing',
        builder: (context, state) => const TeacherLandingScreen(), // Updated to use teacher landing screen
      ),
      GoRoute(
        path: '/teacher-landing',
        builder: (context, state) => const TeacherLandingScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'preferences',
            builder: (context, state) => const PreferencesScreen(),
          ),
          GoRoute(
            path: 'data-storage',
            builder: (context, state) => const DataStorageScreen(),
          ),
          GoRoute(
            path: 'privacy-about',
            builder: (context, state) => const PrivacyAboutScreen(),
          ),
          GoRoute(
            path: 'subscription',
            builder: (context, state) => const SubscriptionScreen(),
          ),
          GoRoute(
            path: 'account-profile',
            builder: (context, state) => const AccountProfileScreen(),
          ),
          GoRoute(
            path: 'referral',
            builder: (context, state) => const ReferralScreen(),
          ),
        ],
      ),

      // Main application shell with bottom navigation bar
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          // Branch 1: Home (formerly Review)
          StatefulShellBranch(
            navigatorKey: _reviewShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                // Home Route (Responsive)
                path: '/',
                builder: (context, state) => const ResponsiveView(
                  mobile: ReviewScreen(),
                  desktop: ReviewScreenWeb(),
                ),
                routes: [],
              ),
            ],
          ),

          // Branch 2: Library
          StatefulShellBranch(
            navigatorKey: _libraryShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/library',
                builder: (context, state) => const ResponsiveView(
                  mobile: LibraryScreen(),
                  desktop: LibraryScreenWeb(),
                ),
                routes: [
                  // Sub-routes accessible from the Library tab
                  GoRoute(
                    path: 'summary',
                    parentNavigatorKey:
                        _rootNavigatorKey, // Show without nav bar
                    builder: (context, state) {
                      final summary = state.extra as LocalSummary?;
                      return SummaryScreen(summary: summary);
                    },
                  ),
                  GoRoute(
                    path: 'quiz',
                    parentNavigatorKey:
                        _rootNavigatorKey, // Show without nav bar
                    builder: (context, state) {
                      final quiz = state.extra as LocalQuiz?;
                      return QuizScreen(quiz: quiz);
                    },
                  ),
                  GoRoute(
                    path: 'flashcards',
                    parentNavigatorKey:
                        _rootNavigatorKey, // Show without nav bar
                    builder: (context, state) {
                      final set = state.extra as FlashcardSet?;
                      return FlashcardsScreen(flashcardSet: set);
                    },
                  ),
                  GoRoute(
                    path: 'results-view/:folderId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ResponsiveView(
                      mobile: ResultsViewScreen(
                          folderId: state.pathParameters['folderId']!),
                      desktop: ResultsViewScreenWeb(
                          folderId: state.pathParameters['folderId']!),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Branch 3: Create
          StatefulShellBranch(
            navigatorKey: _createShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                  path: '/create',
                  builder: (context, state) => const ResponsiveView(
                        mobile: CreateContentScreen(),
                        desktop: CreateContentScreenWeb(),
                      ),
                  routes: [
                    GoRoute(
                      path: 'extraction-view',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => ResponsiveView(
                        mobile: ExtractionViewScreen(
                            result: state.extra as ExtractionResult?),
                        desktop: ExtractionViewScreenWeb(
                            result: state.extra as ExtractionResult?),
                      ),
                    ),
                    GoRoute(
                      path: 'edit-content',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        if (state.extra is EditableContent) {
                          final content = state.extra as EditableContent;
                          if (content.type == 'quiz') {
                            return EditQuizScreen(content: content);
                          } else if (content.type == 'flashcards' ||
                              content.type == 'flashcardSet' ||
                              content.type == 'flashcard') {
                            return EditFlashcardsScreen(content: content);
                          } else if (content.type == 'summary') {
                            final summary = Summary(
                              id: content.id,
                              userId: '',
                              title: content.title,
                              content: content.content ?? '',
                              timestamp: content.timestamp,
                              tags: content.tags ?? [],
                            );
                            return EditScreen(item: summary);
                          } else {
                            return const Scaffold(
                                body: Center(
                                    child: Text(
                                        'Unknown Content Type for Editing')));
                          }
                        } else {
                          // Should return a valid widget, like an error screen
                          return const Scaffold(
                              body: Center(child: Text('Invalid Content')));
                        }
                      },
                    ),
                  ]),
            ],
          ),

          // Branch 4: Progress
          StatefulShellBranch(
            navigatorKey: _progressShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                  path: '/progress',
                  builder: (context, state) => const ResponsiveView(
                        mobile: ProgressScreen(),
                        desktop: ProgressScreenWeb(),
                      ),
                  routes: []),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/deck',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          if (id == null) {
            return const Scaffold(
                body: Center(child: Text('Invalid Deck Link')));
          }
          return PublicDeckScreen(deckId: id);
        },
      ),
      GoRoute(
        path: '/edit_profile',
        builder: (context, state) => const EditCreatorProfileScreen(),
      ),
      GoRoute(
        path: '/creator_dashboard',
        builder: (context, state) => const CreatorDashboardScreen(),
      ),
      GoRoute(
        path: '/exam-creation',
        builder: (context, state) => const ExamCreationScreen(), // Add exam creation route
      ),
    ],
  );
}
