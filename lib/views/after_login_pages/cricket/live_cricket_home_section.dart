import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/live_cricket_provider.dart';
import 'live_match_card_widget.dart';
import 'live_matches_screen.dart';

class LiveCricketHomeSection extends StatelessWidget {
  const LiveCricketHomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LiveCricketProvider(),
      child: Consumer<LiveCricketProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.matches.isEmpty) {
            return const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            );
          }

          if (provider.matches.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Header: Title on left ('Live Sport'), Explore button on right
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Live Sport',
                          style: text18(color: AppColors.black, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LiveMatchesScreen()),
                        );
                      },
                      child: Row(
                        children: [
                          Text('Explore', style: text13(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Horizontal Match Cards List (Matching reference card proportions)
              SizedBox(
                height: 285,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.matches.length,
                  itemBuilder: (context, index) {
                    final match = provider.matches[index];
                    return LiveMatchCardWidget(match: match);
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
