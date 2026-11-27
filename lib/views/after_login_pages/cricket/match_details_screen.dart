import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/live_match_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/empty_state_widget.dart';
import '../../../utils/entitlement_helper.dart';
import '../../../utils/error_state_widget.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/live_cricket_provider.dart';
import '../profile_page/subsrciption_screen.dart';

/// Screen presenting details for a specific cricket match.
///
/// Manages 25-second live score polling while active, and automatically
/// stops polling upon disposal or navigation exit.
class MatchDetailsScreen extends StatefulWidget {
  final String matchId;
  final LiveMatchModel? initialMatch;

  const MatchDetailsScreen({
    super.key,
    required this.matchId,
    this.initialMatch,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  LiveCricketProvider? _cricketProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cricketProvider = context.read<LiveCricketProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LiveCricketProvider>();
      if (widget.initialMatch != null) {
        provider.setSelectedMatch(widget.initialMatch!);
      }
      provider.fetchMatchDetails(widget.matchId);

      // Start 25-second polling if the match is currently live
      if (widget.initialMatch?.isLive == true) {
        provider.startLiveScorePolling(widget.matchId);
      }
    });
  }

  @override
  void dispose() {
    // Explicitly cancel polling and clear selection on screen exit
    _cricketProvider?.stopLiveScorePolling();
    _cricketProvider?.clearSelectedMatch();
    super.dispose();
  }

  void _handleWatchLive(BuildContext context, LiveMatchModel match) {
    if (!EntitlementHelper.canWatchLiveMatch(context, match)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting Live Stream for ${match.displayTitle}...'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LiveCricketProvider>();
    final match = provider.selectedMatch ?? widget.initialMatch;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'CATCH',
                style: text20(color: AppColors.primary, fontWeight: FontWeight.w900),
              ),
              TextSpan(
                text: 'WATCH',
                style: text20(color: AppColors.black, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        centerTitle: false,
      ),
      body: provider.isDetailLoading && match == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : provider.detailError != null && match == null
              ? ErrorStateWidget(
                  title: 'Unable to load match details',
                  message: provider.detailError,
                  onRetry: () => provider.fetchMatchDetails(widget.matchId),
                )
              : match == null
                  ? const EmptyStateWidget(
                      title: 'Match Not Found',
                      message: 'The requested match could not be found.',
                      icon: Icons.sports_cricket_outlined,
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await provider.fetchMatchDetails(widget.matchId);
                      },
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hero Match Card
                            _buildHeroMatchCard(match),

                            const SizedBox(height: 16),

                            // Action Buttons
                            _buildActionButtons(context, match),

                            const SizedBox(height: 20),

                            // Info Pills Row
                            _buildInfoPills(match),

                            const SizedBox(height: 20),

                            // Match Summary Section (if statusNote or description available)
                            if (match.statusNote != null && match.statusNote!.isNotEmpty) ...[
                              _buildSectionTitle('Match Summary'),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.grey50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.grey200),
                                ),
                                child: Text(
                                  match.statusNote!,
                                  style: appTextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Scorecard Overview (Actual API scores)
                            if (match.team1?.score != null || match.team2?.score != null) ...[
                              _buildSectionTitle('Scorecard Overview'),
                              const SizedBox(height: 8),
                              _buildScorecardTile(match.team1),
                              const SizedBox(height: 8),
                              _buildScorecardTile(match.team2),
                              const SizedBox(height: 20),
                            ],

                            // Match Details Table
                            _buildSectionTitle('Match Details'),
                            const SizedBox(height: 8),
                            _buildDetailsTable(match),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildHeroMatchCard(LiveMatchModel match) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: match.banner != null && match.banner!.isNotEmpty
                  ? Image.network(
                      match.banner!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackHeroBackground(),
                    )
                  : _buildFallbackHeroBackground(),
            ),

            // Gradient
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

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Top Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLiveBadge(match.isLive),
                      if (match.series != null)
                        Flexible(
                          child: Text(
                            match.series!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text12(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      if (match.viewerCount > 0)
                        Row(
                          children: [
                            const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${match.viewerCount}',
                              style: text11(color: Colors.white70),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Teams & Scores
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeroTeamColumn(match.team1),
                      Text('VS', style: text14(color: Colors.white70, fontWeight: FontWeight.w900)),
                      _buildHeroTeamColumn(match.team2),
                    ],
                  ),

                  if (match.statusNote != null && match.statusNote!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        match.statusNote!,
                        textAlign: TextAlign.center,
                        style: text11(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroTeamColumn(TeamModel? team) {
    final name = team?.displayName ?? 'TBD';
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
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
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '🏏',
                        style: text18(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '🏏',
                      style: text18(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: text13(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        if (team?.score != null) ...[
          const SizedBox(height: 2),
          Text(
            team!.score!,
            style: text12(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, LiveMatchModel match) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _handleWatchLive(context, match),
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
              label: Text(
                match.isLive ? 'Watch Live' : 'Watch Stream',
                style: text15(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppColors.grey100,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textPrimary, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing match info...')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPills(LiveMatchModel match) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (match.startTime != null)
            _buildPill(
              icon: Icons.calendar_today_rounded,
              title: _formatDate(match.startTime!),
              subtitle: _formatTime(match.startTime!),
            ),
          if (match.venue != null && match.venue!.isNotEmpty)
            _buildPill(
              icon: Icons.location_on_outlined,
              title: match.venue!,
              subtitle: 'Venue',
            ),
          if (match.series != null && match.series!.isNotEmpty)
            _buildPill(
              icon: Icons.emoji_events_outlined,
              title: match.series!,
              subtitle: match.matchType ?? 'Tournament',
            ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text12(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: text10(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScorecardTile(TeamModel? team) {
    if (team == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (team.logo != null && team.logo!.isNotEmpty)
                ClipOval(
                  child: Image.network(
                    team.logo!,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.sports_cricket, size: 20),
                  ),
                )
              else
                const Icon(Icons.sports_cricket, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                team.name,
                style: text14(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Text(
            team.score != null
                ? '${team.score!}${team.overs != null ? ' (${team.overs} ov)' : ''}'
                : 'Yet to bat',
            style: text13(
              color: team.score != null ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTable(LiveMatchModel match) {
    final rows = <MapEntry<String, String>>[];
    if (match.matchType != null) rows.add(MapEntry('Format', match.matchType!));
    if (match.venue != null) rows.add(MapEntry('Venue', match.venue!));
    if (match.series != null) rows.add(MapEntry('Tournament', match.series!));
    if (match.statusNote != null) rows.add(MapEntry('Status', match.statusNote!));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final isLast = i == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.grey200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(rows[i].key, style: text13(color: AppColors.textSecondary)),
                Flexible(
                  child: Text(
                    rows[i].value,
                    textAlign: TextAlign.end,
                    style: text13(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: text15(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildLiveBadge(bool isLive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLive ? const Color(0xFFE50914) : Colors.white24,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isLive ? '• LIVE' : 'UPCOMING',
        style: text10(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildFallbackHeroBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_getMonth(dt.month)} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _getMonth(int month) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? m[month - 1] : '';
  }
}
