import 'package:catch_watch/main.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/view_model/after_login_provider/chat_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('🎨 [STARTUP] SplashScreen initState entered');
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      try {
        if (HiveService.isLogin()) {
          Provider.of<ChatProvider>(context, listen: false).ensureReady();
          Navigator.pushReplacementNamed(context, '/home');
        } else if (HiveService.isOnboardingCompleted()) {
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint('❌ [STARTUP] SplashScreen navigation error: $e\n$stack');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('🎨 [STARTUP] SplashScreen build rendered');
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // अगर image use karna hai (recommended)
              Image.asset(
                "assets/images/logo.jpg",
                width: 100,
                height: 100,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.play_circle_fill,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
