import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/live_match_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/empty_state_widget.dart';
import '../../../utils/error_state_widget.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/live_cricket_provider.dart';
import 'widgets/live_match_card.dart';

/// Screen displaying Live, Upcoming, and Completed cricket matches with filters.
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
  late int _selectedTab;
  String _selectedTournament = 'All Tournaments';
  String _selectedFormat = 'All Formats';

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
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
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAllCricketData(),
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Hero Top Banner
            SliverToBoxAdapter(child: _buildHeroBanner()),

            // Segmented Pill Tabs
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildPillTabs(provider),
              ),
            ),

            // Filter Dropdowns Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildFilterRow(provider),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Match List Content
            _buildMatchListSliver(provider),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D1B2A),
            Color(0xFF1B263B),
            Color(0xFF415A77),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Live ',
                        style: text24(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                      TextSpan(
                        text: 'Cricket',
                        style: text24(color: AppColors.primary, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Watch Live Matches, Scores & Updates',
                  style: text12(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.sports_cricket, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTabs(LiveCricketProvider provider) {
    return Row(
      children: [
        _buildPillTabItem(
          index: 0,
          label: 'Live (${provider.liveMatches.length})',
        ),
        const SizedBox(width: 10),
        _buildPillTabItem(
          index: 1,
          label: 'Upcoming (${provider.upcomingMatches.length})',
        ),
        const SizedBox(width: 10),
        _buildPillTabItem(
          index: 2,
          label: 'Completed (${provider.completedMatches.length})',
        ),
      ],
    );
  }

  Widget _buildPillTabItem({required int index, required String label}) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.grey300,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: text12(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow(LiveCricketProvider provider) {
    final currentList = _getCurrentList(provider);
    final tournaments = <String>{'All Tournaments'};
    final formats = <String>{'All Formats'};

    for (final m in currentList) {
      if (m.series != null && m.series!.isNotEmpty) tournaments.add(m.series!);
      if (m.matchType != null && m.matchType!.isNotEmpty) formats.add(m.matchType!);
    }

    return Row(
      children: [
        // Tournament Dropdown
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: tournaments.contains(_selectedTournament) ? _selectedTournament : 'All Tournaments',
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                style: text12(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                items: tournaments.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTournament = val);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Format Dropdown
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: formats.contains(_selectedFormat) ? _selectedFormat : 'All Formats',
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                style: text12(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                items: formats.map((f) {
                  return DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFormat = val);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<LiveMatchModel> _getCurrentList(LiveCricketProvider provider) {
    switch (_selectedTab) {
      case 0:
        return provider.liveMatches;
      case 1:
        return provider.upcomingMatches;
      case 2:
        return provider.completedMatches;
      default:
        return <LiveMatchModel>[];
    }
  }

  bool _isLoading(LiveCricketProvider provider) {
    switch (_selectedTab) {
      case 0:
        return provider.isLiveLoading;
      case 1:
        return provider.isUpcomingLoading;
      case 2:
        return provider.isCompletedLoading;
      default:
        return false;
    }
  }

  String? _getError(LiveCricketProvider provider) {
    switch (_selectedTab) {
      case 0:
        return provider.liveError;
      case 1:
        return provider.upcomingError;
      case 2:
        return provider.completedError;
      default:
        return null;
    }
  }

  Widget _buildMatchListSliver(LiveCricketProvider provider) {
    final isLoading = _isLoading(provider);
    final error = _getError(provider);
    final rawList = _getCurrentList(provider);

    if (isLoading && rawList.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (error != null && rawList.isEmpty) {
      return SliverFillRemaining(
        child: ErrorStateWidget(
          title: 'Unable to load matches',
          message: error,
          onRetry: () => provider.fetchAllCricketData(),
        ),
      );
    }

    // Apply Filter
    final filtered = rawList.where((m) {
      if (_selectedTournament != 'All Tournaments' && m.series != _selectedTournament) {
        return false;
      }
      if (_selectedFormat != 'All Formats' && m.matchType != _selectedFormat) {
        return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      final tabTitle = _selectedTab == 0
          ? 'No Live Matches'
          : _selectedTab == 1
              ? 'No Upcoming Matches'
              : 'No Completed Matches';
      return SliverFillRemaining(
        child: EmptyStateWidget(
          title: tabTitle,
          message: 'Check back soon for new cricket fixtures and live broadcasts.',
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
