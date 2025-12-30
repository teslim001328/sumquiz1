import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/editable_content.dart';
import 'package:sumquiz/models/flashcard_set.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/views/screens/auth_screen.dart';
import 'package:sumquiz/views/screens/library_screen.dart';
import 'package:sumquiz/views/screens/progress_screen.dart';
import 'package:sumquiz/views/screens/settings_screen.dart';
import 'package:sumquiz/views/screens/review_screen.dart';
import 'package:sumquiz/views/screens/summary_screen.dart';
import 'package:sumquiz/views/screens/quiz_screen.dart';
import 'package:sumquiz/views/screens/flashcards_screen.dart';
import 'package:sumquiz/views/screens/edit_content_screen.dart';
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
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) {
      final user = authService.currentUser;
      final isAuthRoute = state.matchedLocation == '/auth';
      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (isSplash || isOnboarding) {
        return null; // Allow splash and onboarding
      }

      if (user == null) {
        return isAuthRoute
            ? null
            : '/auth'; // If not logged in, redirect to auth
      }

      if (isAuthRoute) {
        return '/'; // If logged in and on auth, redirect to home (library)
      }

      return null;
    },
    routes: <RouteBase>[
      // Top-level routes that should not have the nav bar
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
                path: '/',
                builder: (context, state) => const ReviewScreen(),
                routes: [
                  GoRoute(
                      path: 'settings',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => const SettingsScreen(),
                      routes: [
                        GoRoute(
                          path: 'preferences',
                          builder: (context, state) =>
                              const PreferencesScreen(),
                        ),
                        GoRoute(
                          path: 'data-storage',
                          builder: (context, state) =>
                              const DataStorageScreen(),
                        ),
                        GoRoute(
                          path: 'privacy-about',
                          builder: (context, state) =>
                              const PrivacyAboutScreen(),
                        ),
                        GoRoute(
                          path: 'subscription',
                          builder: (context, state) =>
                              const SubscriptionScreen(),
                        ),
                        GoRoute(
                          path: 'account-profile',
                          builder: (context, state) =>
                              const AccountProfileScreen(),
                        ),
                        GoRoute(
                          path: 'referral',
                          builder: (context, state) => const ReferralScreen(),
                        ),
                      ]),
                ],
              ),
            ],
          ),

          // Branch 2: Library
          StatefulShellBranch(
            navigatorKey: _libraryShellNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryScreen(),
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
                    builder: (context, state) => ResultsViewScreen(
                        folderId: state.pathParameters['folderId']!),
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
                  builder: (context, state) => const CreateContentScreen(),
                  routes: [
                    GoRoute(
                      path: 'extraction-view',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => ExtractionViewScreen(
                          initialText: state.extra as String?),
                    ),
                    GoRoute(
                      path: 'edit-content',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        if (state.extra is EditableContent) {
                          return EditContentScreen(
                              content: state.extra as EditableContent);
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
                  builder: (context, state) => const ProgressScreen(),
                  routes: [
                    GoRoute(
                        path: 'settings',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => const SettingsScreen(),
                        routes: [
                          GoRoute(
                            path: 'preferences',
                            builder: (context, state) =>
                                const PreferencesScreen(),
                          ),
                          GoRoute(
                            path: 'data-storage',
                            builder: (context, state) =>
                                const DataStorageScreen(),
                          ),
                          GoRoute(
                            path: 'privacy-about',
                            builder: (context, state) =>
                                const PrivacyAboutScreen(),
                          ),
                          GoRoute(
                            path: 'subscription',
                            builder: (context, state) =>
                                const SubscriptionScreen(),
                          ),
                          GoRoute(
                            path: 'account-profile',
                            builder: (context, state) =>
                                const AccountProfileScreen(),
                          ),
                          GoRoute(
                            path: 'referral',
                            builder: (context, state) => const ReferralScreen(),
                          ),
                        ]),
                  ]),
            ],
          ),
        ],
      ),
    ],
  );
}
