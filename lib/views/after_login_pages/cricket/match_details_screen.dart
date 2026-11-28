import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../models/live_match_model.dart';
import '../../../models/live_show_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/empty_state_widget.dart';
import '../../../utils/entitlement_helper.dart';
import '../../../utils/error_state_widget.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/live_cricket_provider.dart';
import '../profile_page/subsrciption_screen.dart';

/// Screen presenting details for a specific cricket match matching Catch & Watch UI.
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
  YoutubePlayerController? _youtubeController;
  bool _isPlaying = false;
  int _selectedTab = 2; // Default to Playing XI as seen in screenshot
  int _selectedSquadTeamIndex = 0; // 0 for Team A, 1 for Team B

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cricketProvider = context.read<LiveCricketProvider>();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialMatch != null) {
      _initPlayer(widget.initialMatch);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LiveCricketProvider>();
      if (widget.initialMatch != null) {
        provider.setSelectedMatch(widget.initialMatch!);
      }
      provider.fetchMatchDetails(widget.matchId).then((_) {
        final fetched = provider.selectedMatch;
        if (fetched != null && !_isPlaying) {
          _initPlayer(fetched);
        }
      });

      if (widget.initialMatch?.isLive == true) {
        provider.startLiveScorePolling(widget.matchId);
      }
    });
  }

  void _initPlayer(LiveMatchModel? match) {
    if (match == null) return;
    final ytId = match.youtubeVideoId ?? extractYouTubeId(match.streamUrl);
    if (ytId != null && ytId.isNotEmpty && _youtubeController == null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: ytId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          isLive: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _cricketProvider?.stopLiveScorePolling();
    _cricketProvider?.clearSelectedMatch();
    super.dispose();
  }

  void _handleWatchLive(BuildContext context, LiveMatchModel match) async {
    if (!EntitlementHelper.canWatchLiveMatch(context, match)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      );
      return;
    }

    if (_youtubeController != null) {
      setState(() {
        _isPlaying = true;
      });
    } else if (match.streamUrl != null && match.streamUrl!.isNotEmpty) {
      final uri = Uri.parse(match.streamUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
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
        title: Text(
          match?.title ?? widget.initialMatch?.title ?? 'Match Details',
          style: text16(color: AppColors.black, fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => provider.fetchMatchDetails(widget.matchId),
          ),
        ],
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
                            // 1. Video Player / Stream Banner Card
                            _buildHeroMatchCard(match),

                            const SizedBox(height: 12),

                            // 2. Match Header Meta Row (T20, LIVE NOW, Viewers)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0E8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    match.matchType ?? 'T20',
                                    style: text11(color: AppColors.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE50914),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                          const SizedBox(width: 4),
                                          Text('LIVE NOW', style: text10(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    if (match.viewerCount > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.grey100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.remove_red_eye_outlined, size: 12, color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text('${match.viewerCount}', style: text11(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Title & Venue
                            Text(
                              match.title,
                              style: text18(color: AppColors.black, fontWeight: FontWeight.w900),
                            ),
                            if (match.venue != null && match.venue!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(match.venue!, style: text12(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],

                            const SizedBox(height: 14),

                            // 3. Teams Score Card Box
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.grey200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(8),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _buildTeamScoreRow(match.team1),
                                  const Divider(height: 20, color: AppColors.grey200),
                                  _buildTeamScoreRow(match.team2),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 4. On Crease & Live Activity Card
                            _buildLiveActivityCard(provider),

                            const SizedBox(height: 20),

                            // 5. Tabs Row (Scorecard, Commentary, Playing XI)
                            Container(
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.grey200, width: 1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildTabButton('Scorecard', 0),
                                  _buildTabButton('Commentary', 1),
                                  _buildTabButton('Playing XI', 2),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 6. Tab Content Area
                            _buildTabContent(provider, match),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          style: text14(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(LiveCricketProvider provider, LiveMatchModel match) {
    switch (_selectedTab) {
      case 0:
        return _buildScorecardTabContent(provider, match);
      case 1:
        return _buildCommentaryTabContent(provider);
      case 2:
        return _buildPlayingXiTabContent(provider, match);
      default:
        return const SizedBox();
    }
  }

  Widget _buildPlayingXiTabContent(LiveCricketProvider provider, LiveMatchModel match) {
    final squads = provider.squads;
    final teamAData = squads?['teamA'] ?? squads?['team1'];
    final teamBData = squads?['teamB'] ?? squads?['team2'];

    final teamAName = teamAData?['name'] ?? match.team1?.name ?? 'Team A';
    final teamBName = teamBData?['name'] ?? match.team2?.name ?? 'Team B';

    final playersList = _selectedSquadTeamIndex == 0
        ? (teamAData?['players'] as List?) ?? []
        : (teamBData?['players'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team Toggle Pills
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedSquadTeamIndex = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedSquadTeamIndex == 0 ? const Color(0xFFFFF0E8) : AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedSquadTeamIndex == 0 ? AppColors.primary : AppColors.grey300,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    teamAName,
                    style: text13(
                      color: _selectedSquadTeamIndex == 0 ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedSquadTeamIndex = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedSquadTeamIndex == 1 ? const Color(0xFFFFF0E8) : AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedSquadTeamIndex == 1 ? AppColors.primary : AppColors.grey300,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    teamBName,
                    style: text13(
                      color: _selectedSquadTeamIndex == 1 ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Players List
        if (playersList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Squads available soon',
                style: text13(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Column(
            children: playersList.map<Widget>((player) {
              final name = player['name']?.toString() ?? 'Player';
              final isCaptain = player['isCaptain'] == true;
              final isWicketKeeper = player['isWicketKeeper'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF0E8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sports_cricket, size: 14, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: text14(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isWicketKeeper)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('WK', style: text10(color: AppColors.blue, fontWeight: FontWeight.bold)),
                      ),
                    if (isCaptain)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('C', style: text10(color: AppColors.warning, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildScorecardTabContent(LiveCricketProvider provider, LiveMatchModel match) {
    final scorecard = provider.scorecard;
    final innings1 = scorecard?['innings1'];
    final innings2 = scorecard?['innings2'];

    return Column(
      children: [
        _buildInningsScorecardCard(
          innings1?['teamName'] ?? match.team1?.name ?? 'Team 1',
          innings1?['score'] ?? match.team1?.score ?? 'Yet to bat',
        ),
        const SizedBox(height: 12),
        _buildInningsScorecardCard(
          innings2?['teamName'] ?? match.team2?.name ?? 'Team 2',
          innings2?['score'] ?? match.team2?.score ?? 'Yet to bat',
        ),
      ],
    );
  }

  Widget _buildInningsScorecardCard(String teamName, String score) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(teamName, style: text15(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
              Text(score, style: text14(color: AppColors.primary, fontWeight: FontWeight.w900)),
            ],
          ),
          const Divider(height: 20),
          Text('Batting & bowling details available during play', style: text12(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCommentaryTabContent(LiveCricketProvider provider) {
    final commentaryData = provider.commentary;
    final commentaryList = (commentaryData?['commentary'] as List?) ?? [];

    if (commentaryList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No commentary available yet',
            style: text13(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: commentaryList.map<Widget>((c) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Text(c.toString(), style: text13(color: AppColors.textPrimary)),
        );
      }).toList(),
    );
  }

  Widget _buildLiveActivityCard(LiveCricketProvider provider) {
    final activity = provider.liveActivity;
    final crr = activity?['crr'] ?? activity?['CRR'] ?? '0.00';
    final striker = activity?['striker'] is Map ? activity!['striker'] : null;
    final nonStriker = activity?['nonStriker'] is Map ? activity!['nonStriker'] : null;
    final bowler = activity?['bowler'] is Map ? activity!['bowler'] : (activity?['currentBowler'] is Map ? activity!['currentBowler'] : null);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_cricket, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text('ON CREASE & LIVE ACTIVITY', style: text12(color: AppColors.primary, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('CRR: $crr', style: text10(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 16, color: AppColors.grey200),
          _buildActivityBatsmanRow(striker, isStriker: true),
          const SizedBox(height: 6),
          _buildActivityBatsmanRow(nonStriker, isStriker: false),
          const Divider(height: 16, color: AppColors.grey200),
          _buildActivityBowlerRow(bowler),
        ],
      ),
    );
  }

  Widget _buildActivityBatsmanRow(Map<String, dynamic>? batsman, {required bool isStriker}) {
    final name = batsman?['name']?.toString() ?? (isStriker ? 'Striker' : 'Non-Striker');
    final runs = batsman?['runs'] ?? 0;
    final balls = batsman?['balls'] ?? 0;
    final fours = batsman?['fours'] ?? 0;
    final sixes = batsman?['sixes'] ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(isStriker ? Icons.sports_cricket : Icons.person_outline, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(name.isNotEmpty ? name : (isStriker ? 'Batsman 1' : 'Batsman 2'), style: text13(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            if (isStriker) ...[
              const SizedBox(width: 4),
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            ],
          ],
        ),
        Text('$runs ($balls b)   4s: $fours | 6s: $sixes', style: text12(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildActivityBowlerRow(Map<String, dynamic>? bowler) {
    final name = bowler?['name']?.toString() ?? 'Bowler';
    final overs = bowler?['overs'] ?? 0;
    final wickets = bowler?['wickets'] ?? 0;
    final runsConceded = bowler?['runsConceded'] ?? bowler?['runs'] ?? 0;
    final econ = bowler?['economy'] ?? '0.0';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.sports_baseball, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(name.isNotEmpty ? name : 'Bowler', style: text13(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ],
        ),
        Text('$runsConceded/$wickets ($overs ov, Econ: $econ)', style: text12(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ],
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
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      team.logo!,
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.flag, size: 24, color: AppColors.primary),
                    ),
                  )
                : const Icon(Icons.flag, size: 24, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              team.name,
              style: text14(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Text(
          team.score != null && team.score!.isNotEmpty ? team.score! : 'Yet to bat',
          style: text13(
            color: team.score != null && team.score!.isNotEmpty ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroMatchCard(LiveMatchModel match) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _isPlaying && _youtubeController != null
            ? YoutubePlayer(
                controller: _youtubeController!,
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  // Background Banner
                  match.banner != null && match.banner!.isNotEmpty
                      ? Image.network(
                          match.banner!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildFallbackHeroBackground(),
                        )
                      : _buildFallbackHeroBackground(),

                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(100),
                          Colors.black.withAlpha(200),
                        ],
                      ),
                    ),
                  ),

                  // Top-left GPL / Sports LIVE Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white,
                          child: Text('🏏', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.series ?? 'Cricket Tournament',
                              style: text12(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Sports LIVE',
                              style: text10(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Center Play Button Overlay
                  Center(
                    child: GestureDetector(
                      onTap: () => _handleWatchLive(context, match),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(128),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                      ),
                    ),
                  ),

                  // Bottom Stream Bar
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.live_tv, color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Stream • ${match.series ?? match.title}',
                              style: text11(color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('HD YouTube', style: text10(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
}
