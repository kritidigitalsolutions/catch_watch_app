import 'package:catch_watch/utils/custom_button.dart';
import 'package:catch_watch/views/before_login_Pages/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../res/app_colors.dart';
import '../../utils/text_style.dart';
import '../../view_model/before_login_provider/auth_providers.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // PageView
          PageView.builder(
            controller: provider.pageController,
            onPageChanged: provider.onPageChanged,
            itemCount: provider.onboardingData.length,
            itemBuilder: (context, index) {
              return OnboardingPage(item: provider.onboardingData[index]);
            },
          ),

          // Skip Button
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              child: Text(
                "Skip",
                style: text14(
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          ),

          // Bottom Content
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Dots Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    provider.onboardingData.length,
                        (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: provider.currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: provider.currentPage == index
                            ? AppColors.primary
                            : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Next / Get Started Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: AppButton(title:  provider.currentPage == provider.onboardingData.length - 1
                      ? "Get Started"
                      : "Next",
                  onTap: (){
                    if (provider.currentPage < provider.onboardingData.length - 1) {
                      provider.nextPage();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    }
                  },
                  ),
                )

              ],
            ),
          ),
        ],
      ),
    );
  }
}


class OnboardingPage extends StatelessWidget {
  final OnboardingItem item;

  const OnboardingPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image
        Image.asset(
          item.image,
          fit: BoxFit.cover,
        ),

        // Dark Gradient Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.transparent,
                AppColors.black.withOpacity(0.4),
                AppColors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),

        // Text Content
        Positioned(
          bottom: 220,
          left: 30,
          right: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                item.title,

                style: text26(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.subtitle,
                textAlign: TextAlign.center,
                style: appTextStyle(
                  color: AppColors.white.withOpacity(0.9),
                  height: 1.4,
                  fontSize: 16
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}