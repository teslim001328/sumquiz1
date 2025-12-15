import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/local_database_service.dart';
import 'package:myapp/models/user_model.dart';
import 'firebase_options.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/view_models/quiz_view_model.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:myapp/router/app_router.dart';
import 'package:myapp/providers/navigation_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:myapp/services/iap_service.dart';
import 'package:myapp/services/usage_service.dart';
import 'package:myapp/services/referral_service.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/view_models/referral_view_model.dart';
import 'package:myapp/services/content_extraction_service.dart';
import 'package:myapp/services/spaced_repetition_service.dart';
import 'package:myapp/services/mission_service.dart';
import 'package:myapp/services/time_sync_service.dart';
import 'package:myapp/services/error_reporting_service.dart';
import 'package:myapp/widgets/notification_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // HIGH PRIORITY FIX H8: Crash Reporting / Logging
  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) async {
    final errorReportingService = ErrorReportingService();
    await errorReportingService.reportError(
        details.exception, details.stack ?? StackTrace.current,
        context: 'Flutter Framework Error');
  };

  // Handle async errors
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final errorReportingService = ErrorReportingService();
    errorReportingService.reportError(error, stack,
        context: 'Unhandled Async Error');
    return true;
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LocalDatabaseService().init();

  final notificationService = NotificationService();
  await notificationService.initialize();

  // Initialize error reporting service
  // HIGH PRIORITY FIX H8: Crash Reporting / Logging
  final errorReportingService = ErrorReportingService();

  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  }

  final authService = AuthService(FirebaseAuth.instance);

  // CRITICAL FIX C3: Sync time with server to prevent device time manipulation
  await TimeSyncService.syncWithServer();

  runApp(MyApp(
      authService: authService, notificationService: notificationService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  final NotificationService notificationService;

  const MyApp(
      {super.key,
      required this.authService,
      required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        Provider<AuthService>.value(value: authService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<AIService>(create: (_) => AIService()),
        Provider<ContentExtractionService>(
            create: (_) => ContentExtractionService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<LocalDatabaseService>(create: (_) => LocalDatabaseService()),
        Provider<SpacedRepetitionService>(
            create: (context) => SpacedRepetitionService(
                context.read<LocalDatabaseService>().getSpacedRepetitionBox())),
        ProxyProvider4<FirestoreService, LocalDatabaseService,
            SpacedRepetitionService, NotificationService, MissionService>(
          update: (context, firestore, localDb, srs, notificationService,
                  previous) =>
              MissionService(
            firestoreService: firestore,
            localDb: localDb,
            srs: srs,
            notificationService: notificationService,
          ),
        ),
        ProxyProvider<AuthService, IAPService?>(
          update: (context, authService, previous) {
            final user = authService.currentUser;
            if (user != null) {
              if (previous != null) {
                return previous;
              }
              final service = IAPService();
              service.initialize();
              return service;
            }
            previous?.dispose();
            return null;
          },
          dispose: (_, service) => service?.dispose(),
        ),
        ProxyProvider<AuthService, UsageService?>(
          update: (context, authService, previous) {
            final user = authService.currentUser;
            if (user != null) {
              return UsageService(user.uid);
            }
            return null;
          },
        ),
        ProxyProvider<AuthService, ReferralService>(
          update: (context, authService, previous) {
            return ReferralService();
          },
        ),
        StreamProvider<UserModel?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
        ),
        ChangeNotifierProxyProvider<AuthService, QuizViewModel>(
          create: (context) => QuizViewModel(
            LocalDatabaseService(),
            context.read<AuthService>(),
          ),
          update: (_, authService, previous) {
            if (previous != null) {
              return previous;
            }
            return QuizViewModel(LocalDatabaseService(), authService);
          },
        ),
        ChangeNotifierProxyProvider<AuthService, ReferralViewModel>(
          create: (context) => ReferralViewModel(
              context.read<ReferralService>(), context.read<AuthService>()),
          update: (context, authService, previous) {
            previous?.update(context.read<ReferralService>(), authService);
            return previous!;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final router = createAppRouter(authService);
          return NotificationNavigator(
            child: MaterialApp.router(
              title: 'SumQuiz',
              theme: themeProvider.getTheme(),
              darkTheme: themeProvider.getTheme(),
              themeMode: themeProvider.themeMode,
              routerConfig: router,
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                FlutterQuillLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en', ''),
              ],
            ),
          );
        },
      ),
    );
  }
}
