import 'package:flutter/material.dart';
import '../../../../models/live_match_model.dart';
import '../../../../res/app_colors.dart';
import '../../../../utils/text_style.dart';
import '../match_details_screen.dart';

/// Hero Featured Cricket Match Card matching Catch & Watch design.
class FeaturedMatchCard extends StatelessWidget {
  final LiveMatchModel match;
  final VoidCallback? onWatchLive;

  const FeaturedMatchCard({
    super.key,
    required this.match,
    this.onWatchLive,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailsScreen(matchId: match.id, initialMatch: match),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background Image / Stadium
              Positioned.fill(
                child: match.banner != null && match.banner!.isNotEmpty
                    ? Image.network(
                        match.banner!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackBackground(),
                      )
                    : _buildFallbackBackground(),
              ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Row: Tournament & Live Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Tournament with Trophy Icon
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.emoji_events_outlined,
                                color: Colors.amber,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  match.series ?? match.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text13(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status Badge
                        _buildStatusBadge(),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Teams & Score Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Team 1
                        _buildTeamColumn(match.team1, isLeft: true),

                        // Center VS / Score
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'VS',
                            style: text14(
                              color: Colors.white70,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),

                        // Team 2
                        _buildTeamColumn(match.team2, isLeft: false),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Translucent Score Summary Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text(
                                match.team1?.score != null
                                    ? '${match.team1!.displayName} ${match.team1!.score!}${match.team1?.overs != null ? ' (${match.team1!.overs} ov)' : ''}'
                                    : '${match.team1?.displayName ?? "Team 1"} - Yet to bat',
                                style: text12(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '|',
                                style: text12(color: Colors.white38),
                              ),
                              Text(
                                match.team2?.score != null
                                    ? '${match.team2!.displayName} ${match.team2!.score!}${match.team2?.overs != null ? ' (${match.team2!.overs} ov)' : ''}'
                                    : '${match.team2?.displayName ?? "Team 2"} - Yet to bat',
                                style: text12(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          if (match.statusNote != null && match.statusNote!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              match.statusNote!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: text11(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Watch Live Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          if (onWatchLive != null) {
                            onWatchLive!();
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MatchDetailsScreen(
                                  matchId: match.id,
                                  initialMatch: match,
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              match.isLive ? 'Watch Live' : 'Match Details',
                              style: text14(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamColumn(TeamModel? team, {required bool isLeft}) {
    final name = team?.displayName ?? 'TBD';
    return Expanded(
      child: Column(
        children: [
          // Circular Team Crest
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white30, width: 2),
            ),
            child: ClipOval(
              child: team?.logo != null && team!.logo!.isNotEmpty
                  ? Image.network(
                      team.logo!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackCrest(name),
                    )
                  : _buildFallbackCrest(name),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text13(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCrest(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '🏏',
        style: text16(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (match.isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE50914), // Red live badge
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            Text(
              'LIVE',
              style: text11(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    if (match.isUpcoming) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'UPCOMING',
          style: text10(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'COMPLETED',
        style: text10(color: Colors.white70, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
        ),
      ),
    );
  }
}
