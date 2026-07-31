import 'package:flutter/material.dart';
import '../../res/app_colors.dart';
import '../../utils/text_style.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

enum LeaderboardFilter { day, week, month, year }

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardFilter _selectedFilter = LeaderboardFilter.week;

  final List<Map<String, dynamic>> _dummyUsers = [
    {"name": "Alex Johnson", "points": 15400, "rank": 1, "image": null},
    {"name": "Sarah Miller", "points": 14200, "rank": 2, "image": null},
    {"name": "Mike Ross", "points": 13800, "rank": 3, "image": null},
    {"name": "Jessica Pearson", "points": 12500, "rank": 4, "image": null},
    {"name": "Harvey Specter", "points": 11900, "rank": 5, "image": null},
    {"name": "Donna Paulsen", "points": 11200, "rank": 6, "image": null},
    {"name": "Louis Litt", "points": 10500, "rank": 7, "image": null},
    {"name": "Rachel Zane", "points": 9800, "rank": 8, "image": null},
    {"name": "Robert Zane", "points": 8700, "rank": 9, "image": null},
    {"name": "Katrina Bennett", "points": 7500, "rank": 10, "image": null},
  ];

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _dummyUsers.length - 3,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.grey100),
              itemBuilder: (context, index) {
                final user = _dummyUsers[index + 3];
                return _buildLeaderboardTile(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
        children: [
          _buildTopRankItem(_dummyUsers[1], 2, 70), // Rank 2
          _buildTopRankItem(_dummyUsers[0], 1, 90), // Rank 1
          _buildTopRankItem(_dummyUsers[2], 3, 70), // Rank 3
        ],
      ),
    );
  }

  Widget _buildTopRankItem(Map<String, dynamic> user, int rank, double size) {
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
                  child: const Icon(Icons.person, color: Colors.white),
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
        Text(
          user['name'],
          style: text12(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        Text(
          "${user['points']} pts",
          style: text10(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: LeaderboardFilter.values.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedFilter = filter),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    filter.name.toUpperCase(),
                    style: text10(
                      color: isSelected ? Colors.white : AppColors.grey600,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLeaderboardTile(Map<String, dynamic> user) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              "#${user['rank']}",
              style: text12(color: AppColors.grey600, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.grey100,
            child: Icon(Icons.person, size: 20, color: AppColors.grey400),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              user['name'],
              style: text14(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            "${user['points']} pts",
            style: text14(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
