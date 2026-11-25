import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../models/live_cricket_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../utils/universal_image.dart';
import '../../../view_model/after_login_provider/live_cricket_provider.dart';

class LiveMatchDetailScreen extends StatefulWidget {
  final String matchId;

  const LiveMatchDetailScreen({super.key, required this.matchId});

  @override
  State<LiveMatchDetailScreen> createState() => _LiveMatchDetailScreenState();
}

class _LiveMatchDetailScreenState extends State<LiveMatchDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LiveCricketProvider(),
      child: _MatchDetailView(matchId: widget.matchId, tabController: _tabController),
    );
  }
}

class _MatchDetailView extends StatefulWidget {
  final String matchId;
  final TabController tabController;

  const _MatchDetailView({required this.matchId, required this.tabController});

  @override
  State<_MatchDetailView> createState() => _MatchDetailViewState();
}

class _MatchDetailViewState extends State<_MatchDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LiveCricketProvider>().loadMatchDetails(widget.matchId);
    });
  }

  @override
  void dispose() {
    context.read<LiveCricketProvider>().stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LiveCricketProvider>();
    final match = provider.currentMatchDetail;
    final crease = provider.liveCrease;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          match?.title ?? 'Live Match',
          style: text16(color: AppColors.black, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => provider.loadMatchDetails(widget.matchId),
          ),
        ],
      ),
      body: provider.isDetailLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : match == null
              ? Center(child: Text('Failed to load match details.', style: text14(color: AppColors.error)))
              : RefreshIndicator(
                  onRefresh: () => provider.loadMatchDetails(widget.matchId),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Video Stream Player Banner
                      _LiveVideoPlayerWidget(match: match),
                      const SizedBox(height: 16),

                      // Match Status Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              match.format ?? 'T20',
                              style: text12(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Row(
                            children: [
                              if (match.status == 'LIVE' || match.isLive == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
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
                              const SizedBox(width: 8),
                              if (match.viewerCount != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.grey200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.remove_red_eye, size: 12, color: AppColors.grey700),
                                      const SizedBox(width: 4),
                                      Text('${match.viewerCount}', style: text11(color: AppColors.grey800, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        match.title ?? '',
                        style: text18(color: AppColors.black, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.grey500),
                          const SizedBox(width: 4),
                          Text(match.venue ?? '', style: text12(color: AppColors.grey600)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Teams & Scores Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.grey300),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 3))],
                        ),
                        child: Column(
                          children: [
                            _buildTeamScoreRow(match.team1),
                            const Divider(height: 20),
                            _buildTeamScoreRow(match.team2),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Latest Ticker Banner
                      if (match.latestTicker != null && match.latestTicker!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withAlpha(60)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  match.latestTicker!,
                                  style: text13(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // On Crease & Live Activity Card
                      if (crease != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withAlpha(80)),
                            boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(15), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.sports_cricket, color: AppColors.primary, size: 18),
                                      const SizedBox(width: 6),
                                      Text('ON CREASE & LIVE ACTIVITY', style: text12(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  if (crease.currentRunRate != null || match.currentRunRate != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                                      child: Text(
                                        'CRR: ${crease.currentRunRate ?? match.currentRunRate}',
                                        style: text11(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Striker
                              if (crease.striker != null)
                                _buildBatsmanRow(crease.striker!, isStriker: true),
                              const SizedBox(height: 8),
                              // Non-Striker
                              if (crease.nonStriker != null)
                                _buildBatsmanRow(crease.nonStriker!, isStriker: false),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              // Current Bowler
                              if (crease.currentBowler != null)
                                _buildBowlerRow(crease.currentBowler!),

                              // Recent Balls
                              if (crease.recentBalls != null && crease.recentBalls!.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text('RECENT BALLS:', style: text10(color: AppColors.grey600, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: crease.recentBalls!.reversed.map((ball) {
                                      final isFour = ball == '4';
                                      final isSix = ball == '6';
                                      final isWicket = ball.toUpperCase() == 'W';
                                      final isWd = ball.toUpperCase().contains('WD');
                                      final isNb = ball.toUpperCase().contains('NB');

                                      Color bg = AppColors.grey200;
                                      Color fg = AppColors.black;
                                      if (isFour) {
                                        bg = AppColors.success;
                                        fg = Colors.white;
                                      } else if (isSix) {
                                        bg = AppColors.primary;
                                        fg = Colors.white;
                                      } else if (isWicket) {
                                        bg = AppColors.error;
                                        fg = Colors.white;
                                      } else if (isWd || isNb) {
                                        bg = AppColors.warning;
                                        fg = Colors.white;
                                      }

                                      return Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: bg,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            ball,
                                            style: text11(color: fg, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Tabs: Scorecard, Commentary, Playing XI
                      Column(
                        children: [
                          TabBar(
                            controller: widget.tabController,
                            indicatorColor: AppColors.primary,
                            indicatorWeight: 3,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.grey700,
                            labelStyle: text13(fontWeight: FontWeight.bold),
                            tabs: const [
                              Tab(text: 'Scorecard'),
                              Tab(text: 'Commentary'),
                              Tab(text: 'Playing XI'),
                            ],
                          ),
                          const Divider(height: 1, thickness: 1, color: AppColors.grey300),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tab Views
                      SizedBox(
                        height: 500,
                        child: TabBarView(
                          controller: widget.tabController,
                          children: [
                            _buildScorecardTab(provider.scorecard),
                            _buildCommentaryTab(provider.commentary),
                            _buildSquadsTab(provider.squads),
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
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.flag, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name ?? '', style: text14(color: AppColors.black, fontWeight: FontWeight.bold)),
                if (team.isBatting == true)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.success.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                    child: Text('Batting', style: text10(color: AppColors.success, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
        Text(
          team.score != null && team.score!.isNotEmpty
              ? '${team.score} ${team.overs != null && !team.score!.contains('ov') ? '(${team.overs} ov)' : ''}'
              : 'Yet to bat',
          style: text16(
            color: team.isBatting == true ? AppColors.primary : AppColors.grey700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBatsmanRow(BatsmanStat batsman, {required bool isStriker}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isStriker ? AppColors.primary.withAlpha(10) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isStriker ? Icons.sports_cricket : Icons.person, size: 16, color: isStriker ? AppColors.primary : AppColors.grey600),
              const SizedBox(width: 6),
              Text(
                batsman.name ?? '',
                style: text13(color: AppColors.black, fontWeight: FontWeight.bold),
              ),
              if (isStriker) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                  child: Text('*', style: text10(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          Row(
            children: [
              Text('${batsman.runs ?? 0}', style: text14(color: AppColors.black, fontWeight: FontWeight.bold)),
              Text(' (${batsman.balls ?? 0}b)', style: text12(color: AppColors.grey600)),
              const SizedBox(width: 12),
              Text('4s: ${batsman.fours ?? 0} | 6s: ${batsman.sixes ?? 0}', style: text11(color: AppColors.grey700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBowlerRow(BowlerStat bowler) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.sports_baseball, size: 16, color: AppColors.grey700),
            const SizedBox(width: 6),
            Text(bowler.name ?? '', style: text13(color: AppColors.black, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(
          '${bowler.wickets ?? 0}/${bowler.runs ?? 0} (${bowler.overs ?? '0'} ov, Econ: ${bowler.economy ?? '0.0'})',
          style: text12(color: AppColors.grey700, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildScorecardTab(ScorecardModel? scorecard) {
    if (scorecard == null || scorecard.innings1 == null) {
      return Center(child: Text('Scorecard not available yet.', style: text14(color: AppColors.grey600)));
    }
    final inn1 = scorecard.innings1!;
    final inn2 = scorecard.innings2;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildInningsCard(inn1),
        if (inn2 != null && (inn2.totalScore != null || (inn2.batting != null && inn2.batting!.isNotEmpty))) ...[
          const SizedBox(height: 16),
          _buildInningsCard(inn2),
        ],
      ],
    );
  }

  Widget _buildInningsCard(InningsScorecard inn) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${inn.teamName ?? 'Innings'} Score', style: text14(color: AppColors.black, fontWeight: FontWeight.bold)),
                Text('${inn.totalScore ?? '0'}', style: text14(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Batting table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 40,
              columns: const [
                DataColumn(label: Text('Batter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Dismissal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('R', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('B', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('4s', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('6s', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('SR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: (inn.batting ?? []).map((b) {
                return DataRow(cells: [
                  DataCell(Text(b.batsman ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                  DataCell(Text(b.dismissal ?? 'not out', style: const TextStyle(color: AppColors.grey600, fontSize: 11))),
                  DataCell(Text('${b.runs ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataCell(Text('${b.balls ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${b.fours ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${b.sixes ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(b.strikeRate ?? '0.0', style: const TextStyle(fontSize: 12))),
                ]);
              }).toList(),
            ),
          ),
          if (inn.extras != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Extras: ${inn.extras}', style: text12(color: AppColors.grey700, fontWeight: FontWeight.w600)),
            ),
          const Divider(height: 1),
          // Bowling table
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Bowling Figures', style: text13(color: AppColors.black, fontWeight: FontWeight.bold)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 40,
              columns: const [
                DataColumn(label: Text('Bowler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('O', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('M', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('R', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('W', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Econ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: (inn.bowling ?? []).map((bowler) {
                return DataRow(cells: [
                  DataCell(Text(bowler.bowler ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                  DataCell(Text(bowler.overs ?? '0', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${bowler.maidens ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${bowler.runs ?? 0}', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${bowler.wickets ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataCell(Text(bowler.economy ?? '0.0', style: const TextStyle(fontSize: 12))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentaryTab(List<CommentaryItem> commentary) {
    if (commentary.isEmpty) {
      return Center(child: Text('No commentary available.', style: text14(color: AppColors.grey600)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: commentary.length,
      itemBuilder: (context, index) {
        final item = commentary[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grey300),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    item.overBall ?? '',
                    style: text12(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.text ?? '',
                  style: text13(color: AppColors.black),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSquadsTab(SquadsInfo? squads) {
    if (squads == null || (squads.team1Squad == null && squads.team2Squad == null)) {
      return Center(child: Text('Playing XI squads not available.', style: text14(color: AppColors.grey600)));
    }
    final t1Squad = squads.team1Squad ?? [];
    final t2Squad = squads.team2Squad ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team 1 Column
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(4),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  squads.team1Name ?? 'Team 1',
                  style: text12(color: AppColors.primary, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              ...t1Squad.map((p) => _buildPlayerTile(p)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Team 2 Column
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(4),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  squads.team2Name ?? 'Team 2',
                  style: text12(color: AppColors.primary, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              ...t2Squad.map((p) => _buildPlayerTile(p)),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getRoleIcon(String? role) {
    switch (role?.toUpperCase()) {
      case 'BATSMAN':
        return Icons.sports_cricket;
      case 'BOWLER':
        return Icons.sports_baseball;
      case 'ALL_ROUNDER':
        return Icons.star_rounded;
      case 'WICKET_KEEPER':
        return Icons.sports_handball;
      default:
        return Icons.person;
    }
  }

  Widget _buildPlayerTile(SquadMember player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(_getRoleIcon(player.role), size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    player.name ?? '',
                    style: text12(color: AppColors.black, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (player.isCaptain == true)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.warning.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                  child: Text('C', style: text10(color: AppColors.warning, fontWeight: FontWeight.bold)),
                ),
              if (player.isWicketKeeper == true && player.role?.toUpperCase() != 'WICKET_KEEPER')
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.info.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                  child: Text('WK', style: text10(color: AppColors.info, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveVideoPlayerWidget extends StatefulWidget {
  final CricketMatch match;

  const _LiveVideoPlayerWidget({required this.match});

  @override
  State<_LiveVideoPlayerWidget> createState() => _LiveVideoPlayerWidgetState();
}

class _LiveVideoPlayerWidgetState extends State<_LiveVideoPlayerWidget> {
  VideoPlayerController? _videoController;
  YoutubePlayerController? _ytController;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isYoutube = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    final url = widget.match.streamUrl ?? '';
    if (url.isEmpty) return;

    if (url.contains('youtube') || url.contains('youtu.be') || widget.match.streamType == 'youtube') {
      _isYoutube = true;
      final videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId != null) {
        _ytController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
          ),
        );
        _isInitialized = true;
        _isPlaying = true;
      }
    } else {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
            _videoController?.play();
            _videoController?.setLooping(true);
            _isPlaying = true;
          }
        }).catchError((_) {
          if (mounted) setState(() => _hasError = true);
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumb = widget.match.banner ?? widget.match.streamThumbnailUrl;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isYoutube && _ytController != null)
              YoutubePlayer(controller: _ytController!)
            else if (_isInitialized && _videoController != null && !_hasError)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else ...[
              thumb != null && thumb.isNotEmpty
                  ? UniversalImage(
                      url: thumb,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 220,
                    )
                  : Container(color: AppColors.grey900),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withAlpha(200)],
                  ),
                ),
              ),
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (!_isInitialized) {
                      _initPlayer();
                    } else {
                      setState(() {
                        if (_isYoutube) {
                          if (_isPlaying) {
                            _ytController?.pause();
                            _isPlaying = false;
                          } else {
                            _ytController?.play();
                            _isPlaying = true;
                          }
                        } else {
                          if (_isPlaying) {
                            _videoController?.pause();
                            _isPlaying = false;
                          } else {
                            _videoController?.play();
                            _isPlaying = true;
                          }
                        }
                      });
                    }
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(100), blurRadius: 10)],
                    ),
                    child: Icon(
                      _isInitialized && _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ],
            Positioned(
              bottom: 8,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.live_tv, color: AppColors.primary, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Stream • ${widget.match.tournament ?? ''}',
                            style: text11(color: Colors.white, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(150),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('HD', style: text10(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenVideoScreen(
                                streamUrl: widget.match.streamUrl ?? '',
                                isYoutube: _isYoutube,
                                ytController: _ytController,
                              ),
                            ),
                          );
                        },
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
}

class FullScreenVideoScreen extends StatefulWidget {
  final String streamUrl;
  final bool isYoutube;
  final YoutubePlayerController? ytController;

  const FullScreenVideoScreen({
    super.key,
    required this.streamUrl,
    required this.isYoutube,
    this.ytController,
  });

  @override
  State<FullScreenVideoScreen> createState() => _FullScreenVideoScreenState();
}

class _FullScreenVideoScreenState extends State<FullScreenVideoScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    if (!widget.isYoutube) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _initialized = true);
            _controller?.play();
            _controller?.setLooping(true);
          }
        });
    }
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
          if (_showControls) _startHideTimer();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: widget.isYoutube && widget.ytController != null
                  ? YoutubePlayer(controller: widget.ytController!)
                  : _initialized && _controller != null
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )
                      : const CircularProgressIndicator(color: AppColors.primary),
            ),
            if (_showControls)
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
