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
    this.width = 280,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLive = match.isLive;

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
        width: width,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: isLive ? const Color(0xFF161F2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive ? Colors.transparent : AppColors.grey200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar: Status Badge + Tournament
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBadge(isLive),
                    if (match.matchType != null && match.matchType!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLive
                              ? Colors.white.withOpacity(0.12)
                              : AppColors.grey100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          match.matchType!,
                          style: text10(
                            color: isLive ? Colors.white70 : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Center: Teams & Scores
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Team 1
                    Expanded(
                      child: Column(
                        children: [
                          _buildCrest(match.team1, isLive),
                          const SizedBox(height: 4),
                          Text(
                            match.team1?.displayName ?? 'TBD',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text13(
                              color: isLive ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (match.team1?.score != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              match.team1!.score!,
                              style: text11(
                                color: isLive ? Colors.white70 : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // VS or Center Info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'VS',
                        style: text12(
                          color: isLive ? Colors.white38 : AppColors.grey400,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    // Team 2
                    Expanded(
                      child: Column(
                        children: [
                          _buildCrest(match.team2, isLive),
                          const SizedBox(height: 4),
                          Text(
                            match.team2?.displayName ?? 'TBD',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text13(
                              color: isLive ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (match.team2?.score != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              match.team2!.score!,
                              style: text11(
                                color: isLive ? Colors.white70 : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Note or Timing
              if (match.statusNote != null && match.statusNote!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Text(
                    match.statusNote!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: text11(
                      color: isLive ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                )
              else if (match.startTime != null && match.isUpcoming)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        _formatStartTime(match.startTime!),
                        style: text11(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Bottom Bar: Tournament
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isLive
                      ? Colors.white.withOpacity(0.06)
                      : AppColors.grey50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                ),
                child: Text(
                  match.series ?? match.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text11(
                    color: isLive ? Colors.white60 : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(bool isLive) {
    if (isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE50914),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'LIVE',
              style: text10(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    if (match.isUpcoming) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0E8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              'Upcoming',
              style: text10(color: AppColors.primary, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.grey200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '✔ Completed',
        style: text10(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildCrest(TeamModel? team, bool isLive) {
    final name = team?.displayName ?? 'TBD';
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLive ? Colors.white.withOpacity(0.12) : AppColors.grey100,
        border: Border.all(
          color: isLive ? Colors.white24 : AppColors.grey300,
          width: 1,
        ),
      ),
      child: ClipOval(
        child: team?.logo != null && team!.logo!.isNotEmpty
            ? Image.network(
                team.logo!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildFallbackCrest(name, isLive),
              )
            : _buildFallbackCrest(name, isLive),
      ),
    );
  }

  Widget _buildFallbackCrest(String name, bool isLive) {
    return Center(
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '🏏',
        style: text14(
          color: isLive ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _formatStartTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isTomorrow = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day + 1;

    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute $period';

    if (isToday) return 'Today, $timeStr';
    if (isTomorrow) return 'Tomorrow, $timeStr';
    return '${dt.day}/${dt.month}, $timeStr';
  }
}
