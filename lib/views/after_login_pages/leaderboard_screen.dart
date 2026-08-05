import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/leaderboard_model.dart';
import '../../res/app_colors.dart';
import '../../utils/text_style.dart';
import '../../view_model/after_login_provider/wallet_provider.dart';
import '../../view_model/after_login_provider/profile_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

// enum LeaderboardFilter { day, week, month, year } // Removed as we use TimeFilter from WalletProvider

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

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final leaderboard = walletProvider.leaderboardData?.leaderboard ?? [];

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
      bottomNavigationBar: _buildMyRankTile(walletProvider),
      body: walletProvider.isLoading && leaderboard.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: () => walletProvider.fetchLeaderboard(range: _selectedTimeframe),
              child: _buildBody(walletProvider, leaderboard),
            ),
    ));
  }

  Widget _buildBody(WalletProvider provider, List<LeaderboardUser> leaderboard) {
    if (provider.error != null) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
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

    if (leaderboard.isEmpty) {
      return ListView(
        children: [
          _buildHeader(leaderboard),
          _buildTimeframeSelector(provider),
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          const Center(child: Text("No rankings found for this period")),
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

  Widget _buildMyRankTile(WalletProvider walletProvider) {
    final profileProvider = context.watch<ProfileProvider>();
    final user = profileProvider.user;
    final rank = walletProvider.leaderboardData?.currentUserRank;

    if (user == null || rank == null || rank <= 0) return const SizedBox.shrink();

    // Try to find current user in the list to get their period points
    final leaderboard = walletProvider.leaderboardData?.leaderboard ?? [];
    final currentUserInList = leaderboard.firstWhere(
      (u) => u.id == user.id,
      orElse: () => LeaderboardUser(rank: rank, periodPoints: 0),
    );

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
                  "#$rank",
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
                    "${currentUserInList.periodPoints ?? 0}",
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
              if (user.blueTick == true) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified_rounded, color: Colors.blue, size: 12),
              ],
            ],
          ),
          Text(
            "${user.periodPoints ?? 0} pts",
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
                    if (user.blueTick == true) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, color: Colors.blue, size: 14),
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
            "${user.periodPoints ?? 0} pts",
            style: text14(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
