import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/leaderboard_model.dart';
import '../../res/app_colors.dart';
import '../../utils/empty_state_widget.dart';
import '../../utils/text_style.dart';
import '../../view_model/after_login_provider/wallet_provider.dart';
import '../../view_model/after_login_provider/profile_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _selectedTimeframe = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchLeaderboard(range: _selectedTimeframe);
      final profileProvider = context.read<ProfileProvider>();
      if (profileProvider.user == null) {
        profileProvider.fetchProfile();
      }
    });
  }

  int _getUserPoints(LeaderboardUser user) {
    if (_selectedTimeframe == 'all') {
      if (user.totalPoints != null && user.totalPoints! > 0) {
        return user.totalPoints!;
      }
      return user.periodPoints ?? 0;
    }
    return user.periodPoints ?? user.totalPoints ?? 0;
  }

  String _getTimeframeLabel(String filter) {
    switch (filter) {
      case 'today':
        return 'Today';
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      case 'year':
        return 'This Year';
      default:
        return 'All Time';
    }
  }

  List<LeaderboardUser> _getFilteredLeaderboard(List<LeaderboardUser> rawLeaderboard) {
    List<LeaderboardUser> list = List.from(rawLeaderboard);
    if (_selectedTimeframe != 'all') {
      final hasPeriodPoints = list.any((u) => (u.periodPoints ?? 0) > 0);
      if (hasPeriodPoints) {
        list.sort((a, b) => (b.periodPoints ?? 0).compareTo(a.periodPoints ?? 0));
        list = list.asMap().entries.map((entry) {
          final idx = entry.key;
          final u = entry.value;
          return LeaderboardUser(
            rank: idx + 1,
            id: u.id,
            name: u.name,
            username: u.username,
            profileImage: u.profileImage,
            blueTick: u.blueTick,
            qualityScore: u.qualityScore,
            creatorLevel: u.creatorLevel,
            totalPoints: u.totalPoints,
            periodPoints: u.periodPoints,
            qualifiedViews: u.qualifiedViews,
            watchMinutes: u.watchMinutes,
            reelsCount: u.reelsCount,
            followersCount: u.followersCount,
            badges: u.badges,
          );
        }).toList();
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final rawLeaderboard = walletProvider.leaderboardData?.leaderboard ?? [];
    final leaderboard = _getFilteredLeaderboard(rawLeaderboard);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text("Leaderboard", style: text18(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        bottomNavigationBar: _buildMyRankTile(walletProvider, leaderboard),
        body: RefreshIndicator(
          onRefresh: () => walletProvider.fetchLeaderboard(range: _selectedTimeframe),
          child: _buildBody(walletProvider, leaderboard),
        ),
      ),
    );
  }

  Widget _buildBody(WalletProvider provider, List<LeaderboardUser> leaderboard) {
    if (provider.error != null) {
      return ListView(
        children: [
          _buildTimeframeSelector(provider),
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 16),
          Center(
            child: Text(
              "Failed to load leaderboard",
              style: text16(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: text12(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: () => provider.fetchLeaderboard(range: _selectedTimeframe),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text("Try Again", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    }

    if (provider.isLoading) {
      return ListView(
        children: [
          _buildTimeframeSelector(provider),
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ],
      );
    }

    if (leaderboard.isEmpty) {
      return ListView(
        children: [
          _buildTimeframeSelector(provider),
          const SizedBox(height: 24),
          EmptyStateWidget(
            title: "No Rankings Found",
            message: "No rankings are available for ${_getTimeframeLabel(_selectedTimeframe).toLowerCase()}.",
            icon: Icons.leaderboard_outlined,
            isScrollable: false,
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildHeader(leaderboard),
        _buildTimeframeSelector(provider),
        const SizedBox(height: 10),
        leaderboard.length <= 3
            ? const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(child: Text("No more users to display")),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: leaderboard.length - 3,
                separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.grey100),
                itemBuilder: (context, index) {
                  final user = leaderboard[index + 3];
                  return _buildLeaderboardTile(user);
                },
              ),
      ],
    );
  }

  Widget _buildTimeframeSelector(WalletProvider walletProvider) {
    final filters = ['all', 'today', 'week', 'month', 'year'];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: filters.map((filter) {
          bool isSelected = _selectedTimeframe == filter;
          return Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedTimeframe == filter && !walletProvider.isLoading) return;
                setState(() => _selectedTimeframe = filter);
                walletProvider.fetchLeaderboard(range: filter);
              },
              borderRadius: BorderRadius.circular(25),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    filter == 'all' ? 'All' : (filter[0].toUpperCase() + filter.substring(1)),
                    style: text12(
                      color: isSelected ? Colors.white : AppColors.grey600,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMyRankTile(WalletProvider walletProvider, List<LeaderboardUser> leaderboard) {
    if (walletProvider.isLoading) return const SizedBox.shrink();

    final profileProvider = context.watch<ProfileProvider>();
    final user = profileProvider.user;
    final serverRank = walletProvider.leaderboardData?.currentUserRank;

    if (user == null) return const SizedBox.shrink();

    // Try to find current user in the list to get their points and rank
    final currentUserInList = leaderboard.firstWhere(
      (u) => u.id == user.id,
      orElse: () => LeaderboardUser(
        rank: serverRank,
        periodPoints: 0,
        totalPoints: 0,
      ),
    );

    final displayRank = currentUserInList.rank ?? serverRank;
    if (displayRank == null || displayRank <= 0) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          margin: const EdgeInsets.fromLTRB(15, 0, 15, 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "#$displayRank",
                  style: text12(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 15),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.grey200,
                backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                    ? NetworkImage(user.profileImage!)
                    : null,
                child: user.profileImage == null || user.profileImage!.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name ?? 'You',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text14(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Text(" 🎊", style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${_getUserPoints(currentUserInList)}",
                    style: text16(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "points",
                    style: text10(color: AppColors.grey600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<LeaderboardUser> leaderboard) {
    final top3 = leaderboard.take(3).toList();
    // Reorder for UI (2nd, 1st, 3rd)
    final displayOrder = <LeaderboardUser>[];
    if (top3.length >= 2) displayOrder.add(top3[1]);
    if (top3.isNotEmpty) displayOrder.add(top3[0]);
    if (top3.length >= 3) displayOrder.add(top3[2]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: displayOrder.map((user) {
          int rank = user.rank ?? 0;
          double size = rank == 1 ? 90 : 70;
          return _buildTopRankItem(user, rank, size);
        }).toList(),
      ),
    );
  }

  Widget _buildTopRankItem(LeaderboardUser user, int rank, double size) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey[300]! : Colors.brown[300]!),
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: size / 2,
                    backgroundColor: AppColors.grey200,
                    backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                        ? NetworkImage(user.profileImage!)
                        : null,
                    child: user.profileImage == null || user.profileImage!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey[300]! : Colors.brown[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "#$rank",
                    style: text10(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  user.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text12(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              if (user.hasVerifiedTick) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified_rounded, color: AppColors.primary, size: 12),
              ],
            ],
          ),
          Text(
            "${_getUserPoints(user)} pts",
            style: text10(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile(LeaderboardUser user) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              "#${user.rank}",
              style: text12(color: AppColors.grey600, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.grey100,
            backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                ? NetworkImage(user.profileImage!)
                : null,
            child: user.profileImage == null || user.profileImage!.isEmpty
                ? const Icon(Icons.person, size: 20, color: AppColors.grey400)
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.name ?? '',
                      style: text14(fontWeight: FontWeight.w600),
                    ),
                    if (user.hasVerifiedTick) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, color: AppColors.primary, size: 14),
                    ],
                  ],
                ),
                if (user.badges != null && user.badges!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      user.badges!.join(', '),
                      style: text10(color: Colors.amber[800]!, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            "${_getUserPoints(user)} pts",
            style: text14(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
