import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/custom_nav_bar.dart';
import 'package:catch_watch/view_model/after_login_provider/home_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/movie_details_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/video_upload_provider.dart';
import 'package:catch_watch/view_model/before_login_provider/auth_providers.dart';
import 'package:catch_watch/views/before_login_Pages/onboarding_screen.dart';
import 'package:catch_watch/views/before_login_Pages/splash_screen.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.white,
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
        ChangeNotifierProvider(create: (_) => MovieDetailProvider()),
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
            systemNavigationBarColor: AppColors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: 0,
              backgroundColor: AppColors.white,
              automaticallyImplyLeading: false,
            ),
            backgroundColor: AppColors.white,

            // Separate Bottom Navigation
            bottomNavigationBar: BottomNavBar(
              currentIndex: ctr.pageIndex,
              onTap: (index) {
                ctr.changePage(index);
              },
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
        );
      },
    );
  }

  // Helper Widge
}
