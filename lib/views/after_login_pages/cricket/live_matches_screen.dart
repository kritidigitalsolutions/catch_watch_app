import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/live_cricket_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../utils/universal_image.dart';
import '../../../view_model/after_login_provider/live_cricket_provider.dart';
import 'live_match_detail_screen.dart';

class LiveMatchesScreen extends StatelessWidget {
  const LiveMatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LiveCricketProvider(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Live Cricket Matches & Fixtures',
            style: text16(color: AppColors.black, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () {
                context.read<LiveCricketProvider>().fetchLiveCricketData();
              },
            ),
          ],
        ),
        body: Consumer<LiveCricketProvider>(
          builder: (context, provider, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STATUS', style: text10(color: AppColors.grey600, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['ALL', 'LIVE', 'UPCOMING', 'COMPLETED'].map((status) {
                            final isSelected = provider.selectedStatus == status;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(status),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                labelStyle: text12(
                                  color: isSelected ? Colors.white : AppColors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (_) {
                                  provider.setFilters(status: status);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('FORMAT', style: text10(color: AppColors.grey600, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['ALL', 'T20', 'ODI', 'TEST', 'LEAGUE'].map((format) {
                            final isSelected = provider.selectedFormat == format;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(format),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                labelStyle: text12(
                                  color: isSelected ? Colors.white : AppColors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (_) {
                                  provider.setFilters(format: format);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Matches List
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : provider.error != null
                          ? Center(child: Text(provider.error!, style: text14(color: AppColors.error)))
                          : provider.matches.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.sports_cricket, size: 64, color: AppColors.grey400),
                                      const SizedBox(height: 16),
                                      Text('No matches found for selected filter.', style: text14(color: AppColors.grey600)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: provider.matches.length,
                                  itemBuilder: (context, index) {
                                    final match = provider.matches[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: _buildVerticalMatchCard(context, match),
                                    );
                                  },
                                ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVerticalMatchCard(BuildContext context, CricketMatch match) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveMatchDetailScreen(matchId: match.id ?? ''),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner & Header (Supports WebP, PNG, JPG, JPEG, SVG, AVIF)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  match.banner != null && match.banner!.isNotEmpty
                      ? UniversalImage(
                          url: match.banner!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(height: 120, color: AppColors.grey800),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withAlpha(180)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(180),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${match.format ?? 'T20'} • ${match.tournament ?? ''}',
                        style: text10(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (match.status == 'LIVE' || match.isLive == true)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text('LIVE', style: text10(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    left: 12,
                    right: 12,
                    child: Text(
                      match.title ?? '',
                      style: text14(color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildTeamRow(match.team1),
                  const SizedBox(height: 6),
                  _buildTeamRow(match.team2),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.grey500),
                          const SizedBox(width: 4),
                          Text(match.venue ?? '', style: text11(color: AppColors.grey600)),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiveMatchDetailScreen(matchId: match.id ?? ''),
                            ),
                          );
                        },
                        child: Text('Watch Broadcast →', style: text12(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRow(TeamInfo? team) {
    if (team == null) return const SizedBox();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            team.logo != null && team.logo!.isNotEmpty
                ? UniversalImage(url: team.logo!, width: 22, height: 22, fit: BoxFit.cover)
                : const Icon(Icons.flag, size: 22),
            const SizedBox(width: 8),
            Text(
              team.name ?? '',
              style: text13(
                color: team.isBatting == true ? AppColors.black : AppColors.grey700,
                fontWeight: team.isBatting == true ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          team.score != null && team.score!.isNotEmpty
              ? '${team.score} ${team.overs != null && !team.score!.contains('ov') ? '(${team.overs} ov)' : ''}'
              : '—',
          style: text13(
            color: team.isBatting == true ? AppColors.primary : AppColors.grey700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
