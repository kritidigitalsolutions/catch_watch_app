import 'package:flutter/material.dart';
import '../../../models/live_cricket_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../utils/universal_image.dart';
import 'live_match_detail_screen.dart';

class LiveMatchCardWidget extends StatelessWidget {
  final CricketMatch match;
  final bool isFullWidth;

  const LiveMatchCardWidget({super.key, required this.match, this.isFullWidth = false});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = isFullWidth ? screenWidth - 32 : (screenWidth * 0.82).clamp(280.0, 400.0);
    final imageUrl = match.banner ?? '';

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
        width: cardWidth,
        margin: EdgeInsets.only(right: isFullWidth ? 0 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large Poster Image & Badges (Height 180 matching Live Show cards)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  imageUrl.isNotEmpty
                      ? UniversalImage(
                          url: imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 180,
                          color: AppColors.grey800,
                          child: const Center(
                            child: Icon(Icons.sports_cricket, color: Colors.white, size: 40),
                          ),
                        ),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withAlpha(160)],
                      ),
                    ),
                  ),
                  // Format & Tournament Tag
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
                        '${match.format ?? 'T20'} • ${match.tournament ?? 'Cricket Series'}',
                        style: text10(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // LIVE Indicator
                  if (match.status == 'LIVE' || match.isLive == true)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('LIVE', style: text10(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Compact Content Area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.title ?? 'Match Title',
                    style: text14(color: AppColors.black, fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Team 1 Score
                  _buildTeamScoreRow(match.team1),
                  const SizedBox(height: 4),
                  // Team 2 Score
                  _buildTeamScoreRow(match.team2),

                  const SizedBox(height: 10),

                  // Latest Ticker / Commentary Snippet
                  if (match.latestTicker != null && match.latestTicker!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: AppColors.primary, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              match.latestTicker!,
                              style: text10(color: AppColors.primary, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamScoreRow(TeamInfo? team) {
    if (team == null) return const SizedBox();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            team.logo != null && team.logo!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: UniversalImage(
                      url: team.logo!,
                      width: 18,
                      height: 18,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.flag, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              team.name ?? 'Team',
              style: text11(
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
          style: text11(
            color: team.isBatting == true ? AppColors.primary : AppColors.grey700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
