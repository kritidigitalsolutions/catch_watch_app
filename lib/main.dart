import 'package:catch_watch/data/network/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/custom_nav_bar.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/legal_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/video_upload_provider.dart';
import 'package:catch_watch/view_model/before_login_provider/auth_providers.dart';
import 'package:catch_watch/views/before_login_Pages/onboarding_screen.dart';
import 'package:catch_watch/views/before_login_Pages/login_screen.dart';
import 'package:catch_watch/views/before_login_Pages/splash_screen.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:catch_watch/view_model/after_login_provider/help_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/notification_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/watchlist_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/user_profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/user_search_provider.dart';

import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/wallet_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/vip_support_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/chat_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/report_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/block_provider.dart';
import 'package:catch_watch/views/after_login_pages/message/call_overlay.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterCryptography.enable();

  if (kDebugMode) {
    debugPrint('🚀 [STARTUP] 1/4 Widgets & Cryptography initialized');
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('❌ [FLUTTER_ERROR] ${details.exceptionAsString()}');
    }
  };

  try {
    try {
      await Firebase.initializeApp();
      if (kDebugMode) {
        debugPrint('🚀 [STARTUP] 2/4 Firebase initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [STARTUP] Firebase initialization warning: $e');
      }
    }

    try {
      await HiveService.init();
      if (kDebugMode) {
        debugPrint('🚀 [STARTUP] 3/4 HiveService initialized');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ [STARTUP] HiveService initialization error: $e\n$stack');
      }
      runApp(StartupErrorApp(
        errorMessage: e.toString(),
        onRetry: () => main(),
      ));
      return;
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    if (kDebugMode) {
      debugPrint('🚀 [STARTUP] 4/4 Calling runApp() immediately');
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OnboardingProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => HomeScreenProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => VideoUploadProvider()),
          ChangeNotifierProvider(create: (_) => LegalProvider()),
          ChangeNotifierProvider(create: (_) => HelpProvider()),
          ChangeNotifierProvider(create: (_) => WatchlistProvider()),
          ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => ReelsProvider()),
          ChangeNotifierProvider(create: (_) => UserProfileProvider()),
          ChangeNotifierProvider(create: (_) => UserSearchProvider()),
          ChangeNotifierProvider(create: (_) => VerificationProvider()),
          ChangeNotifierProvider(create: (_) => WalletProvider()),
          ChangeNotifierProvider(create: (_) => VipSupportProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => CallProvider()),
          ChangeNotifierProvider(create: (_) => ReportProvider()),
          ChangeNotifierProvider(create: (_) => BlockProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Initialize notification service asynchronously so APNs token queries and
    // permission requests never block the main thread or delay initial frame rendering.
    NotificationService.init().then((_) {
      if (kDebugMode) {
        debugPrint('🔔 [STARTUP] Async NotificationService init completed');
      }
    }).catchError((e) {
      if (kDebugMode) {
        debugPrint('⚠️ [STARTUP] NotificationService initialization warning: $e');
      }
    });

    try {
      FirebaseMessaging.onBackgroundMessage(NotificationService.backgroundHandler);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [STARTUP] Firebase background messaging handler registration warning: $e');
      }
    }
  } catch (fatalError, fatalStack) {
    if (kDebugMode) {
      debugPrint('❌ [STARTUP] Fatal startup error: $fatalError\n$fatalStack');
    }
    runApp(StartupErrorApp(
      errorMessage: fatalError.toString(),
      onRetry: () => main(),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: Provider.of<CallProvider>(context, listen: false).navigatorKey,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      builder: (context, child) {
        return CallOverlay(child: child ?? const SizedBox.shrink());
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MyHomePage(),
      },
    );
  }
}

class MyHomePage extends StatelessWidget {
  final int? initialIndex;
  const MyHomePage({super.key, this.initialIndex});

  @override
  Widget build(BuildContext context) {
    final ctr = context.watch<HomeScreenProvider>();
    final uploadProvider = context.watch<VideoUploadProvider>();

    // Set initial index if provided
    if (initialIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctr.changePage(initialIndex!);
      });
    }

    // Auto-navigate to upload tab if data was recovered after a restart
    if (uploadProvider.wasDataRecovered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ctr.pageIndex != 2) {
          ctr.changePage(2);
          uploadProvider.consumeRecoveredData();
        }
      });
    }

    final bool isProfile = ctr.pageIndex == 4;

    return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isProfile ? Brightness.light : Brightness.dark,
            statusBarBrightness: isProfile ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              
              if (ctr.pageIndex != 0) {
                ctr.changePage(0);
              } else {
                final bool shouldExit = await _showExitDialog(context) ?? false;
                if (shouldExit) {
                  SystemNavigator.pop();
                }
              }
            },
            child: Scaffold(
              appBar: isProfile
                  ? null
                  : AppBar(
                      toolbarHeight: 0,
                      backgroundColor: AppColors.white,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                    ),
              backgroundColor: AppColors.white,

              // Separate Bottom Navigation
              bottomNavigationBar: SafeArea(
                child: BottomNavBar(
                  currentIndex: ctr.pageIndex,
                  onTap: (index) {
                    ctr.changePage(index);
                  },
                ),
              ),
  
              body: Consumer<HomeScreenProvider>(
                builder: (context, p, child) {
                  return Stack(
                    children: [
                      // Main Content using IndexedStack
                      IndexedStack(index: p.pageIndex, children: p.screenPage),
                    ],
                  );
                },
              ),
            ),
          ),
        );
  }

  Future<bool?> _showExitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: text14(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes',
              style: text14(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget
}

class StartupErrorApp extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const StartupErrorApp({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.primary,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to Start Catch & Watch',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'An error occurred during startup initialization.\nPlease check your connection and tap Retry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
