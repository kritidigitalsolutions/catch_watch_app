import 'package:flutter/material.dart';
import '../../../models/live_cricket_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../utils/universal_image.dart';
import 'live_match_detail_screen.dart';

class LiveMatchCardWidget extends StatelessWidget {
  final CricketMatch match;

  const LiveMatchCardWidget({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
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
        width: 320,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Banner Image & Tags (Supports WebP, PNG, JPG, JPEG, SVG, AVIF)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  match.banner != null && match.banner!.isNotEmpty
                      ? UniversalImage(
                          url: match.banner!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 140,
                          color: AppColors.grey800,
                          child: const Center(
                            child: Icon(Icons.sports_cricket, color: Colors.white, size: 40),
                          ),
                        ),
                  // Gradient overlay
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withAlpha(180)],
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
                          borderRadius: BorderRadius.circular(12),
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

            // Content Area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.title ?? 'Match Title',
                    style: text14(color: AppColors.black, fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: AppColors.primary, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              match.latestTicker!,
                              style: text11(color: AppColors.primary, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.grey200),
                  const SizedBox(height: 8),

                  // Venue & Watch button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: AppColors.grey500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                match.venue ?? 'Stadium',
                                style: text11(color: AppColors.grey600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Watch →',
                        style: text12(color: AppColors.primary, fontWeight: FontWeight.bold),
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

  Widget _buildTeamScoreRow(TeamInfo? team) {
    if (team == null) return const SizedBox();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            team.logo != null && team.logo!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: UniversalImage(
                      url: team.logo!,
                      width: 20,
                      height: 20,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.flag, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              team.name ?? 'Team',
              style: text12(
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
          style: text12(
            color: team.isBatting == true ? AppColors.primary : AppColors.grey700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
