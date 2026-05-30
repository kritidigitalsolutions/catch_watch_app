import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../res/app_colors.dart';
import '../../utils/custom_button.dart';
import '../../utils/text_style.dart';
import '../../view_model/before_login_provider/auth_providers.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.read<AuthProvider>().goBackToOtp(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              Text(
                'What do you love watching?',
                style: text24(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your favorite genres to personalize your experience.',
                style: text13(color: AppColors.textSecondary),
              ),

              const SizedBox(height: 12),

              // Selected count badge
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: auth.selectedGenres.isNotEmpty
                    ? Container(
                  key: ValueKey(auth.selectedGenres.length),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${auth.selectedGenres.length} selected',
                    style: text12(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                )
                    : const SizedBox(key: ValueKey('empty'), height: 0),
              ),

              const SizedBox(height: 20),

              // Genre chips
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: auth.allGenres.map((genre) {
                      final isSelected = auth.selectedGenres.contains(genre);
                      return GestureDetector(
                        onTap: () =>
                            context.read<AuthProvider>().toggleGenre(genre),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.grey300,
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                color:
                                AppColors.primary.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                genre,
                                style: text13(
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Error message
              if (auth.categoriesError != null) ...[
                const SizedBox(height: 8),
                Text(
                  auth.categoriesError!,
                  style: text12(color: AppColors.error),
                ),
              ],

              const SizedBox(height: 16),

              // Continue button
              AppButton(
                title: 'Continue',

                onTap: (){

                  context.read<AuthProvider>().proceedFromCategories(context);
                },),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}