import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/leaderboard_model.dart';
import '../../res/app_colors.dart';
import '../../utils/text_style.dart';
import '../../view_model/after_login_provider/wallet_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

// enum LeaderboardFilter { day, week, month, year } // Removed as we use TimeFilter from WalletProvider

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final leaderboard = walletProvider.leaderboardData?.leaderboard ?? [];

    return Scaffold(
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
      body: walletProvider.isLoading && leaderboard.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => walletProvider.fetchLeaderboard(),
              child: Column(
                children: [
                  if (walletProvider.error != null)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                            const SizedBox(height: 16),
                            Text(
                              "Failed to load leaderboard",
                              style: text16(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                walletProvider.error!,
                                textAlign: TextAlign.center,
                                style: text12(color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => walletProvider.fetchLeaderboard(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Text("Try Again", style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (leaderboard.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text("No rankings found for this period"),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildHeader(leaderboard),
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
                      ),
                    ),
                ],
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
    return Column(
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
          children: [
            Text(
              user.name ?? '',
              style: text12(color: Colors.white, fontWeight: FontWeight.bold),
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
