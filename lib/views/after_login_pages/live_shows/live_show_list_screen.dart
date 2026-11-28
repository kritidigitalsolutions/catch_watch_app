import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/live_show_model.dart';
import '../../../res/app_colors.dart';
import '../../../utils/empty_state_widget.dart';
import '../../../utils/error_state_widget.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/live_show_provider.dart';
import 'widgets/live_show_card.dart';

/// Screen displaying list of live shows with filter pills (All Shows, Live Now, Upcoming) and Categories.
class LiveShowListScreen extends StatefulWidget {
  const LiveShowListScreen({super.key});

  @override
  State<LiveShowListScreen> createState() => _LiveShowListScreenState();
}

class _LiveShowListScreenState extends State<LiveShowListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All Shows'; // All Shows, Live Now, UPCOMING
  String _selectedCategory = 'All Categories'; // All Categories, Music Concert, Podcast, etc.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LiveShowProvider>().fetchAllLiveShowData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Live Shows & Broadcasts',
          style: text16(color: AppColors.black, fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => context.read<LiveShowProvider>().fetchAllLiveShowData(),
          ),
        ],
      ),
      body: Consumer<LiveShowProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () => provider.fetchAllLiveShowData(),
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Search Bar & Filters Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar
                        TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search live shows, performers...',
                            hintStyle: text13(color: AppColors.grey500),
                            prefixIcon: const Icon(Icons.search, color: AppColors.grey600, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.grey100,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Status Filter Pills (All Shows, Live Now, UPCOMING)
                        _buildStatusPills(),
                        const SizedBox(height: 12),

                        // Categories Horizontal Filter Pills
                        _buildCategoryPills(provider),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // Show List Sliver
                _buildShowListSliver(provider),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusPills() {
    final statuses = ['All Shows', 'Live Now', 'UPCOMING'];
    return Row(
      children: statuses.map((status) {
        final isSelected = _selectedStatus == status;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedStatus = status),
            child: Container(
              margin: EdgeInsets.only(right: status != statuses.last ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
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
                style: text12(
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

  Widget _buildCategoryPills(LiveShowProvider provider) {
    final allShows = <LiveShowModel>[
      ...provider.liveShows,
      ...provider.upcomingShows,
      ...provider.endedShows,
    ];
    final categories = <String>{'All Categories'};
    for (final s in allShows) {
      if (s.category != null && s.category!.isNotEmpty) {
        categories.add(s.category!);
      }
    }
    // Add default sample categories if list is short
    if (categories.length <= 1) {
      categories.addAll(['Music Concert', 'Podcast', 'Talk Show', 'Gaming']);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
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
                cat,
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

  Widget _buildShowListSliver(LiveShowProvider provider) {
    final allShows = <LiveShowModel>[
      ...provider.liveShows,
      ...provider.upcomingShows,
      ...provider.endedShows,
    ];
    // Deduplicate by ID
    final seen = <String>{};
    final uniqueShows = allShows.where((s) => seen.add(s.id)).toList();

    // Filter by status
    final statusFiltered = uniqueShows.where((s) {
      if (_selectedStatus == 'All Shows') return true;
      if (_selectedStatus == 'Live Now') return s.isLive;
      if (_selectedStatus == 'UPCOMING') return s.isUpcoming;
      return true;
    }).toList();

    // Filter by category
    final categoryFiltered = statusFiltered.where((s) {
      if (_selectedCategory == 'All Categories') return true;
      return s.category?.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    // Filter by search query
    final filtered = categoryFiltered.where((s) {
      if (_searchQuery.isEmpty) return true;
      final titleMatch = s.title.toLowerCase().contains(_searchQuery);
      final hostMatch = s.hostName?.toLowerCase().contains(_searchQuery) ?? false;
      final descMatch = s.description?.toLowerCase().contains(_searchQuery) ?? false;
      return titleMatch || hostMatch || descMatch;
    }).toList();

    if (filtered.isEmpty) {
      return const SliverFillRemaining(
        child: EmptyStateWidget(
          title: 'No Live Shows Found',
          message: 'No live shows match your search or filter.',
          icon: Icons.tv_off_rounded,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final show = filtered[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LiveShowCard(
                show: show,
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
