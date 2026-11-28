import 'package:flutter/material.dart';
import '../../../../models/live_match_model.dart';
import '../../../../res/app_colors.dart';
import '../../../../utils/text_style.dart';
import '../match_details_screen.dart';

/// Horizontal & Vertical Live Match Card matching Catch & Watch design.
class LiveMatchCard extends StatelessWidget {
  final LiveMatchModel match;
  final double? width;
  final VoidCallback? onTap;

  const LiveMatchCard({
    super.key,
    required this.match,
    this.width = 310,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLive = match.isLive;
    final bannerUrl = match.banner ?? '';

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchDetailsScreen(matchId: match.id, initialMatch: match),
            ),
          );
        }
      },
      child: Container(
        width: width ?? 310,
        margin: const EdgeInsets.only(right: 16),
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
            // Large Poster Image & Badges (Height 180)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  bannerUrl.isNotEmpty
                      ? Image.network(
                          bannerUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 180,
                            color: AppColors.grey800,
                            child: const Center(
                              child: Icon(Icons.sports_cricket, color: Colors.white, size: 40),
                            ),
                          ),
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
                  // LIVE Indicator Badge (Top Left)
                  if (isLive)
                    Positioned(
                      top: 12,
                      left: 12,
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
                  // Format & Series Tag (Top Right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(180),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        match.matchType ?? 'T20',
                        style: text10(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
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
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.grey200),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        match.venue ?? match.series ?? 'Stadium',
                        style: text11(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Watch Broadcast',
                        style: text12(color: AppColors.primary, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
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

  Widget _buildTeamScoreRow(TeamModel? team) {
    if (team == null) return const SizedBox();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            team.logo != null && team.logo!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      team.logo!,
                      width: 18,
                      height: 18,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.flag, size: 18, color: AppColors.primary),
                    ),
                  )
                : const Icon(Icons.flag, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              team.displayName ?? 'Team',
              style: text11(
                color: AppColors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          team.score ?? '—',
          style: text11(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
