import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/user_profile_screen.dart';
import 'package:provider/provider.dart';

class ChatDetailsScreen extends StatelessWidget {
  final String partnerId;
  final String name;
  final String username;
  final String image;

  const ChatDetailsScreen({
    super.key,
    required this.partnerId,
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
                      backgroundImage: image != null && image.isNotEmpty
                          ? NetworkImage(image)
                          : null,
                      child: image == null || image.isEmpty
                          ? const Icon(Icons.person, size: 50)
                          : null,
                      backgroundColor: AppColors.grey200,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: text20(fontWeight: FontWeight.bold),
                    ),
                    Consumer<ChatProvider>(
                      builder: (context, provider, child) {
                        final status = provider.currentUserStatus;
                        String statusText = "Offline";
                        if (status != null && status.isOnline == true) {
                          statusText = "Online";
                        }
                        return Text(
                          statusText,
                          style: text14(color: statusText == "Online" ? Colors.green : Colors.grey),
                        );
                      },
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
                _buildActionButton(Icons.call_outlined, "Audio", () {
                  Provider.of<CallProvider>(context, listen: false)
                      .startCall(partnerId, 'audio');
                }),
                _buildActionButton(Icons.videocam_outlined, "Video", () {
                  Provider.of<CallProvider>(context, listen: false)
                      .startCall(partnerId, 'video');
                }),
                _buildActionButton(Icons.notifications_off_outlined, "Mute", () {}),
              ],
            ),
            
            const SizedBox(height: 30),
            const Divider(height: 1),
            
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
            Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final isBlocked = chatProvider.isUserBlocked(partnerId);
                return ListTile(
                  title: Text(
                    isBlocked ? "Unblock" : "Block",
                    style: const TextStyle(color: Colors.red),
                  ),
                  trailing: Icon(
                    isBlocked ? Icons.lock_open : Icons.block,
                    color: Colors.red,
                  ),
                  onTap: () {
                    if (isBlocked) {
                      chatProvider.unblockUser(partnerId);
                    } else {
                      _showBlockDialog(context);
                    }
                  },
                );
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
            onPressed: () {
              Provider.of<ChatProvider>(context, listen: false).blockUser(partnerId);
              Navigator.pop(context);
            },
            child: const Text("Block", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
      ),
    );
  }
}
