import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/live_match_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/empty_state_widget.dart';
import '../../../utils/error_state_widget.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/live_cricket_provider.dart';
import 'widgets/live_match_card.dart';

/// Screen displaying Live, Upcoming, and Completed cricket matches with filter pill selectors.
class LiveMatchListScreen extends StatefulWidget {
  final int initialTabIndex; // 0: Live, 1: Upcoming, 2: Completed

  const LiveMatchListScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<LiveMatchListScreen> createState() => _LiveMatchListScreenState();
}

class _LiveMatchListScreenState extends State<LiveMatchListScreen> {
  String _selectedStatus = 'ALL'; // ALL, LIVE, UPCOMING, COMPLETED
  String _selectedFormat = 'ALL'; // ALL, T20, ODI, TEST, LEAGUE

  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex == 0) {
      _selectedStatus = 'LIVE';
    } else if (widget.initialTabIndex == 1) {
      _selectedStatus = 'UPCOMING';
    } else if (widget.initialTabIndex == 2) {
      _selectedStatus = 'COMPLETED';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LiveCricketProvider>();
      provider.fetchAllCricketData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LiveCricketProvider>();

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
          'Live Cricket Matches & Fixtures',
          style: text16(color: AppColors.black, fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => provider.fetchAllCricketData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAllCricketData(),
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Filter Pills Section (Status & Format)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STATUS', style: text11(color: AppColors.textSecondary, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _buildStatusPills(),
                    const SizedBox(height: 16),
                    Text('FORMAT', style: text11(color: AppColors.textSecondary, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _buildFormatPills(),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Match List Content
            _buildMatchListSliver(provider),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPills() {
    final statuses = ['ALL', 'LIVE', 'UPCOMING', 'COMPLETED'];
    return Row(
      children: statuses.map((status) {
        final isSelected = _selectedStatus == status;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedStatus = status),
            child: Container(
              margin: EdgeInsets.only(right: status != statuses.last ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.grey300,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                status,
                style: text11(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFormatPills() {
    final formats = ['ALL', 'T20', 'ODI', 'TEST', 'LEAGUE'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: formats.map((format) {
          final isSelected = _selectedFormat == format;
          return GestureDetector(
            onTap: () => setState(() => _selectedFormat = format),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.grey300,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                format,
                style: text11(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<LiveMatchModel> _getAllMatches(LiveCricketProvider provider) {
    final all = <LiveMatchModel>[
      ...provider.liveMatches,
      ...provider.upcomingMatches,
      ...provider.completedMatches,
    ];
    // Deduplicate by ID
    final seen = <String>{};
    return all.where((m) => seen.add(m.id)).toList();
  }

  Widget _buildMatchListSliver(LiveCricketProvider provider) {
    final rawList = _getAllMatches(provider);

    // Filter by status
    final statusFiltered = rawList.where((m) {
      if (_selectedStatus == 'ALL') return true;
      if (_selectedStatus == 'LIVE') return m.isLive;
      if (_selectedStatus == 'UPCOMING') return m.isUpcoming;
      if (_selectedStatus == 'COMPLETED') return m.isCompleted;
      return true;
    }).toList();

    // Filter by format
    final filtered = statusFiltered.where((m) {
      if (_selectedFormat == 'ALL') return true;
      return m.matchType?.toUpperCase() == _selectedFormat || m.series?.toUpperCase().contains(_selectedFormat) == true;
    }).toList();

    if (filtered.isEmpty) {
      return const SliverFillRemaining(
        child: EmptyStateWidget(
          title: 'No Matches Found',
          message: 'No matches match the selected filters.',
          icon: Icons.sports_cricket_outlined,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final match = filtered[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: LiveMatchCard(
                match: match,
                width: double.infinity,
              ),
            );
          },
          childCount: filtered.length,
        ),
      ),
    );
  }
}
