import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/providers/sync_provider.dart';
import 'package:sumquiz/providers/theme_provider.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/sync_service.dart';
import 'firebase_options.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/services/usage_service.dart';
import 'package:sumquiz/view_models/quiz_view_model.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:sumquiz/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/providers/navigation_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:sumquiz/services/referral_service.dart';
import 'package:sumquiz/services/notification_service.dart';
import 'package:sumquiz/services/user_service.dart';
import 'package:sumquiz/view_models/referral_view_model.dart';
import 'package:sumquiz/services/content_extraction_service.dart';
import 'package:sumquiz/services/spaced_repetition_service.dart';
import 'package:sumquiz/services/mission_service.dart';
import 'package:sumquiz/services/time_sync_service.dart';
import 'package:sumquiz/services/error_reporting_service.dart';
import 'package:sumquiz/widgets/notification_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) async {
    final errorReportingService = ErrorReportingService();
    await errorReportingService.reportError(
        details.exception, details.stack ?? StackTrace.current,
        context: 'Flutter Framework Error');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final errorReportingService = ErrorReportingService();
    errorReportingService.reportError(error, stack,
        context: 'Unhandled Async Error');
    return true;
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await LocalDatabaseService().init();
  } catch (e) {
    debugPrint('Database initialization failed: $e');
    // Consider reporting this error or showing a fatal error screen if DB is critical
    // but for now allow app to launch to at least show 'something'
  }

  final notificationService = NotificationService();
  await notificationService.initialize();

  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
  }

  final authService = AuthService(FirebaseAuth.instance);

  // Non-blocking TimeSync
  TimeSyncService.syncWithServer().then((_) {
    debugPrint('Time synced successfully');
  }).catchError((e) {
    debugPrint('Startup time sync failed: $e');
  });

  runApp(MyApp(
      authService: authService, notificationService: notificationService));
}

class MyApp extends StatefulWidget {
  final AuthService authService;
  final NotificationService notificationService;

  const MyApp(
      {super.key,
      required this.authService,
      required this.notificationService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(widget.authService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        Provider<AuthService>.value(value: widget.authService),
        Provider<NotificationService>.value(value: widget.notificationService),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<LocalDatabaseService>(create: (_) => LocalDatabaseService()),
        Provider<SpacedRepetitionService>(
            create: (context) => SpacedRepetitionService(
                context.read<LocalDatabaseService>().getSpacedRepetitionBox())),
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
        ProxyProvider<IAPService, EnhancedAIService>(
          update: (context, iapService, previous) =>
              EnhancedAIService(iapService: iapService),
        ),
        ProxyProvider<EnhancedAIService, ContentExtractionService>(
          update: (context, enhancedAIService, previous) =>
              ContentExtractionService(enhancedAIService),
        ),
        Provider<UserService>(create: (_) => UserService()),
        Provider<SyncService>(
          create: (context) =>
              SyncService(context.read<LocalDatabaseService>()),
        ),
        ChangeNotifierProvider<QuizViewModel>(
          create: (context) => QuizViewModel(
              context.read<LocalDatabaseService>(),
              context.read<AuthService>()),
        ),
        ChangeNotifierProxyProvider<SyncService, SyncProvider>(
          create: (context) => SyncProvider(context.read<SyncService>()),
          update: (context, syncService, previous) => SyncProvider(syncService),
        ),
        ProxyProvider<AuthService, UsageService?>(
          update: (context, authService, previous) {
            final user = authService.currentUser;
            return user != null ? UsageService() : null;
          },
        ),
        ProxyProvider<AuthService, ReferralService>(
          update: (context, authService, previous) {
            return ReferralService();
          },
        ),
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
        StreamProvider<UserModel?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
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
          return NotificationNavigator(
            child: MaterialApp.router(
              title: 'SumQuiz',
              theme: ThemeProvider.lightTheme,
              darkTheme: ThemeProvider.darkTheme,
              themeMode: themeProvider.themeMode,
              routerConfig: _router,
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
