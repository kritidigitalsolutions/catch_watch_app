import 'package:flutter/material.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/user_profile_screen.dart';

class ChatDetailsScreen extends StatelessWidget {
  final String name;
  final String username;
  final String image;

  const ChatDetailsScreen({
    super.key,
    required this.name,
    required this.username,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text("Details"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Image in Center
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(username: username),
                    ),
                  );
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(image),
                      backgroundColor: AppColors.grey200,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: text20(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Active now",
                      style: text14(color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(Icons.notifications_off_outlined, "Mute"),
                _buildActionButton(Icons.search, "Search"),
                _buildActionButton(Icons.ios_share, "Share"),
              ],
            ),
            
            const SizedBox(height: 30),
            const Divider(height: 1),
            
            // Shared Reels Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Shared Reels",
                    style: text16(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 6,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      childAspectRatio: 0.7,
                    ),
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.grey200,
                          borderRadius: BorderRadius.circular(8),
                          image: const DecorationImage(
                            image: NetworkImage('https://picsum.photos/200/300'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Row(
                                children: [
                                  const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 14),
                                  Text(
                                    "${(index + 1) * 10}k",
                                    style: text10(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // More Info
            const Divider(height: 1),
            ListTile(
              title: const Text("Privacy & Safety"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              title: const Text("Notifications"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              title: const Text("Block", style: TextStyle(color: Colors.red)),
              trailing: const Icon(Icons.block, color: Colors.red),
              onTap: () {
                _showBlockDialog(context);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Block $name?"),
        content: const Text("They won't be able to message you or find your profile on Catch Watch."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Block", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.black),
        ),
        const SizedBox(height: 4),
        Text(label, style: text12()),
      ],
    );
  }
}
