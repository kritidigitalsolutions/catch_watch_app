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
              height: 240,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            );
          }

          if (provider.matches.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header & Explore All Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.live_tv, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Live Cricket Matches',
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
                          const SizedBox(height: 2),
                          Text(
                            'Stream live cricket matches, real-time ball-by-ball scoreboards & tournament broadcasts',
                            style: text11(color: AppColors.grey600),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Explore All Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LiveMatchesScreen()),
                    );
                  },
                  icon: const Text('Explore All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  label: const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Horizontal Match Cards List
              SizedBox(
                height: 335,
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
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
