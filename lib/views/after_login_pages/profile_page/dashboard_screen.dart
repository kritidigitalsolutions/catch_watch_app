import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// import 'package:fl_chart/fl_chart.dart'; // Commented out as it might not be used or causing issues if not in pubspec, but it was there
import 'dart:ui';
import '../../../res/app_colors.dart';
import '../../../utils/error_state_widget.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/profile_provider.dart';
import '../../../view_model/after_login_provider/verification_provider.dart';
import '../../../view_model/after_login_provider/wallet_provider.dart';
import 'wallet_screen.dart';
import '../leaderboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _contentController;
  late Animation<double> _headerGradientAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VerificationProvider>().fetchVerificationStatus();
      context.read<WalletProvider>().fetchDashboardData();
    });
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _headerGradientAnimation = Tween<double>(begin: 0, end: 1).animate(_headerController);

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _contentController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final walletProvider = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(profileProvider, walletProvider),
    );
  }

  Widget _buildBody(ProfileProvider profileProvider, WalletProvider walletProvider) {
    // Metrics are only rendered once a valid dashboard payload exists, so a
    // failed request can never be mistaken for a real all-zero dashboard.
    if (walletProvider.dashboardData == null) {
      if (walletProvider.dashboardError != null) {
        return RefreshIndicator(
          onRefresh: walletProvider.fetchDashboardData,
          child: ErrorStateWidget(
            title: 'Unable to load dashboard',
            message: 'Please check your internet connection and try again.',
            isLoading: walletProvider.isDashboardLoading,
            onRetry: () {
              if (!walletProvider.isDashboardLoading) {
                // Re-uses the currently selected time filter (held in the provider).
                walletProvider.fetchDashboardData();
              }
            },
          ),
        );
      }
      // Initial load (or the brief pre-fetch frame) — existing loader.
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await walletProvider.fetchDashboardData();
      },
      child: CustomScrollView(
        slivers: [
          _buildSliverHeader(profileProvider, walletProvider),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimeFilter(walletProvider),
                  const SizedBox(height: 24),
                  _buildPerformanceScore(walletProvider),
                  const SizedBox(height: 24),
                  _buildLeaderboardCard(),
                  const SizedBox(height: 32),
                  _buildSectionTitle("Performance Summary"),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildStatsGrid(walletProvider),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(ProfileProvider profileProvider, WalletProvider walletProvider) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _headerGradientAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    Color.lerp(AppColors.primary, const Color(0xFFFF8C42), _headerGradientAnimation.value)!,
                    const Color(0xFFCC3D00),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -20,
                    right: -20,
                    child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.1)),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 40,
                    child: CircleAvatar(radius: 30, backgroundColor: Colors.white.withOpacity(0.05)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: CircleAvatar(
                            radius: 35,
                            backgroundImage: profileProvider.user?.profileImage != null && profileProvider.user!.profileImage!.isNotEmpty
                                ? NetworkImage(profileProvider.user!.profileImage!)
                                : null,
                            child: profileProvider.user?.profileImage == null || profileProvider.user!.profileImage!.isEmpty
                                ? const Icon(Icons.person, size: 40)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "👋 Welcome ${profileProvider.name.split(' ')[0]}",
                                    style: text18(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                  if (context.watch<VerificationProvider>().currentApplication?.status == 'approved' || profileProvider.user?.hasVerifiedTick == true) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.verified_rounded, 
                                      color: (profileProvider.user?.blueTick == true) ? Colors.blue : Colors.white, 
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.stars_rounded, color: AppColors.yellow, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${walletProvider.availablePoints} Points",
                                        style: text12(color: Colors.white, fontWeight: FontWeight.bold),
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeFilter(WalletProvider provider) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutBack,
            alignment: _getAlignment(provider.selectedTimeFilter),
            child: FractionallySizedBox(
              widthFactor: 0.2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: TimeFilter.values.map((filter) {
              // Year is disabled until the backend provides year-scoped data
              // (see WalletProvider.setTimeFilter) — shown greyed & non-tappable
              // so all-time values are never presented under the Year filter.
              final isYear = filter == TimeFilter.year;
              final isSelected = provider.selectedTimeFilter == filter;
              return Expanded(
                child: GestureDetector(
                  onTap: isYear
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          provider.setTimeFilter(filter);
                        },
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: Text(
                        _capitalize(filter.name),
                        style: text12(
                          color: isYear
                              ? AppColors.grey400
                              : (isSelected ? AppColors.primary : AppColors.grey600),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Alignment _getAlignment(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.all: return Alignment.centerLeft;
      case TimeFilter.today: return const Alignment(-0.5, 0);
      case TimeFilter.week: return Alignment.center;
      case TimeFilter.month: return const Alignment(0.5, 0);
      case TimeFilter.year: return Alignment.centerRight;
    }
  }

  Widget _buildPerformanceScore(WalletProvider provider) {
    final score = (provider.dashboardData?.qualityScore ?? 0).toDouble();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: score / 100),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    );
                  },
                ),
              ),
              Text(
                "${score.toInt()}%",
                style: text18(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score >= 80 ? "Excellent Performance" : score >= 50 ? "Good Performance" : "Keep Growing!",
                  style: text16(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  "Your creator level is ${provider.dashboardData?.creatorLevel ?? 'Standard'}.",
                  style: text12(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(WalletProvider provider) {
    final data = provider.dashboardData;

    // NOTE: the API does not provide previous-period comparison / growth data,
    // so no growth indicator is rendered (previously a hardcoded 0.0 with a
    // misleading green up-arrow).
    // NOTE: the "Total ..." labels were previously bound to the Year filter,
    // which relabelled all-time values as Year. Year is now disabled (see
    // setTimeFilter), so metrics use plain period labels.
    final stats = [
      ("Points Earned", provider.periodPoints.toString(), Icons.stars_rounded, AppColors.yellow),
      ("Views", provider.currentViews.toString(), Icons.play_circle_fill_rounded, const Color(0xFF6366F1)),
      // NOTE: the API exposes only a single aggregate watch-minutes value
      // (CreatorDashboardData.watchMinutes); it is NOT part of the per-filter
      // timeStats, so it cannot follow the selected time filter. Labelled
      // "Total" to avoid implying a filtered value.
      ("Total Watch Minutes", (data?.watchMinutes ?? 0).toString(), Icons.remove_red_eye_rounded, const Color(0xFFEC4899)),
      ("Likes", provider.currentLikes.toString(), Icons.favorite_rounded, const Color(0xFFEF4444)),
      ("Comments", provider.currentComments.toString(), Icons.comment_rounded, const Color(0xFFF59E0B)),
      ("Shares", provider.currentShares.toString(), Icons.share_rounded, const Color(0xFF10B981)),
      ("Saves", provider.currentSaves.toString(), Icons.bookmark_rounded, const Color(0xFF8B5CF6)),
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final s = stats[index];
            return _buildStatCard(s.$1, s.$2, s.$3, s.$4, index);
          },
          childCount: stats.length,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, int index) {
    // Ensure animation interval is within [0, 1] bounds
    final double start = (index * 0.1).clamp(0.0, 0.5);
    final double end = (start + 0.5).clamp(0.0, 1.0);

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
        CurvedAnimation(parent: _contentController, curve: Interval(start, end, curve: Curves.easeOut)),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _contentController, curve: Interval(start, end, curve: Curves.easeIn)),
        child: _StatCard(label: label, value: value, icon: icon, color: color),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: text18(fontWeight: FontWeight.w800),
    );
  }

  Widget _buildLeaderboardCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFFFF8C42)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Global Leaderboard",
                    style: text16(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "See how you rank among others",
                    style: text12(color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

class _StatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.grey100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                top: -10,
                child: Icon(widget.icon, color: widget.color.withOpacity(0.1), size: 50),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  const Spacer(),
                  _AnimatedCounter(value: int.tryParse(widget.value.replaceAll(',', '')) ?? 0),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: text10(color: AppColors.grey600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedCounter extends StatelessWidget {
  final int value;
  const _AnimatedCounter({required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Text(
          value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
          style: text18(fontWeight: FontWeight.w900),
        );
      },
    );
  }
}
