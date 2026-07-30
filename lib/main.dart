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
import 'package:catch_watch/views/before_login_Pages/splash_screen.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:catch_watch/view_model/after_login_provider/help_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/download_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/notification_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/watchlist_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/user_profile_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await HiveService.init();
  await NotificationService.init();

  FirebaseMessaging.onBackgroundMessage(NotificationService.backgroundHandler);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
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
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
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
    return ChangeNotifierProvider(
      create: (_) => HomeScreenProvider(),
      builder: (context, child) {
        final ctr = Provider.of<HomeScreenProvider>(context);

        // Set initial index if provided
        if (initialIndex != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ctr.changePage(initialIndex!);
          });
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
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
              appBar: AppBar(
                toolbarHeight: 0,
                backgroundColor: AppColors.white,
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
      },
    );
  }

  Future<bool?> _showExitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit App'),
        content: const Text('Are you want to close the app?'),
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

  // Helper Widge
}
