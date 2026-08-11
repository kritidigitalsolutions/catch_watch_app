import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/chat_provider.dart';
import 'package:catch_watch/views/after_login_pages/message/media_preview_screen.dart';
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
  final String conversationId;

  const ChatDetailsScreen({
    super.key,
    required this.partnerId,
    required this.name,
    required this.username,
    required this.image,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text("Details"),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(username: username),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('View Profile'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        if (provider.isUserBlocked(partnerId)) return const SizedBox.shrink();
                        
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
                _buildActionButton(Icons.search, "Search", () {
                  Navigator.pop(context);
                  // In ChatScreen, we could trigger the search UI. 
                  // Since we are popping, we might need a way to tell ChatScreen to open search.
                  // For now, it just goes back.
                }),
                Consumer<ChatProvider>(
                  builder: (context, provider, child) {
                    final isMuted = provider.isMuted(conversationId);
                    return _buildActionButton(
                      isMuted ? Icons.notifications_off : Icons.notifications_active_outlined, 
                      isMuted ? "Unmute" : "Mute", 
                      () => provider.toggleMute(conversationId)
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 30),
            const Divider(height: 1),
            
            // Shared Media Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Images & Videos", style: text16(fontWeight: FontWeight.bold)),
            ),
            Consumer<ChatProvider>(
              builder: (context, provider, child) {
                final mediaMessages = provider.messages.where((m) => 
                  (m.messageType == 'image' || m.messageType == 'video' || m.messageType == 'gif') && 
                  m.mediaUrl != null && m.mediaUrl!.isNotEmpty
                ).toList();

                if (mediaMessages.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text("No media shared yet", style: text14(color: Colors.grey)),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: mediaMessages.length > 6 ? 6 : mediaMessages.length,
                  itemBuilder: (context, index) {
                    final msg = mediaMessages[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MediaPreviewScreen(
                              url: msg.mediaUrl!,
                              type: msg.messageType == 'video' ? 'video' : 'image',
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: msg.messageType == 'video'
                          ? Container(
                              color: Colors.black87,
                              child: const Icon(Icons.play_circle_fill, color: Colors.white),
                            )
                          : Image.network(msg.mediaUrl!, fit: BoxFit.cover),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            
            Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final blockedByMe = chatProvider.isBlockedByMe(partnerId);

                return ListTile(
                  title: Text(
                    blockedByMe ? "Unblock" : "Block",
                    style: const TextStyle(color: Colors.red),
                  ),
                  trailing: Icon(
                    blockedByMe ? Icons.lock_open : Icons.block,
                    color: Colors.red,
                  ),
                  onTap: () {
                    if (blockedByMe) {
                      _showUnblockConfirmation(context, chatProvider);
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

  void _showUnblockConfirmation(BuildContext context, ChatProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Unblock"),
        content: Text("Do you want to unblock $name?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              provider.unblockUser(partnerId);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
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
