import 'package:catch_watch/models/user_model.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/reels_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String title;
  final bool isFollowers;
  final String? userId;

  const FollowersFollowingScreen({
    super.key,
    required this.title,
    required this.isFollowers,
    this.userId,
  });

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isFollowers) {
        context.read<ProfileProvider>().fetchFollowers(userId: widget.userId);
      } else {
        context.read<ProfileProvider>().fetchFollowing(userId: widget.userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, style: text20(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          final users = widget.isFollowers ? provider.followersList : provider.followingList;

          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "No ${widget.title.toLowerCase()} yet",
                    style: text16(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => widget.isFollowers 
                ? provider.fetchFollowers(userId: widget.userId) 
                : provider.fetchFollowing(userId: widget.userId),
            child: ListView.builder(
              itemCount: users.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  onTap: () {
                    if (user.username != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(username: user.username!),
                        ),
                      );
                    }
                  },
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                        ? NetworkImage(user.profileImage!)
                        : null,
                    backgroundColor: AppColors.grey200,
                    child: user.profileImage == null || user.profileImage!.isEmpty
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  ),
                  title: Text(user.name ?? 'Unknown', style: text16(fontWeight: FontWeight.w600)),
                  subtitle: Text(user.username ?? '', style: text14(color: Colors.grey)),
                  trailing: ElevatedButton(
                    onPressed: () async {
                       await provider.toggleFollow(user.id!);
                       if (context.mounted) {
                         context.read<ReelsProvider>().updateFollowStatus(
                           user.id!, 
                           user.isFollowing == true,
                         );
                       }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: user.isFollowing == true 
                          ? Colors.grey.shade200 
                          : AppColors.primary,
                      foregroundColor: user.isFollowing == true 
                          ? Colors.black 
                          : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      user.isFollowing == true ? "Following" : "Follow", 
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
