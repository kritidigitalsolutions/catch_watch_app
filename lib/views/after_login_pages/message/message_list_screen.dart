import 'package:catch_watch/models/chat_model.dart';
import 'package:catch_watch/models/user_model.dart';
import 'package:catch_watch/view_model/after_login_provider/chat_provider.dart';
import 'package:catch_watch/views/after_login_pages/message/call_history_screen.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'chat_screen.dart';

class MessageListScreen extends StatefulWidget {
  const MessageListScreen({super.key});

  @override
  State<MessageListScreen> createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  final TextEditingController _inboxSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false).fetchConversations();
    });
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      DateTime dateTime = DateTime.parse(timeStr).toLocal();
      DateTime now = DateTime.now();
      if (dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year) {
        return DateFormat('hh:mm a').format(dateTime);
      } else if (now.difference(dateTime).inDays < 7) {
        return DateFormat('EEE').format(dateTime);
      } else {
        return DateFormat('dd/MM/yy').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  void _showUserSelection(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final TextEditingController searchController = TextEditingController();

    // Fetch following list when opening
    profileProvider.fetchFollowing();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("New Message", style: text18(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search people...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          profileProvider.fetchFollowing();
                        } else {
                          chatProvider.searchUsers(value);
                        }
                      },
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: Consumer2<ChatProvider, ProfileProvider>(
                    builder: (context, chatProvider, profileProvider, child) {
                      final bool isSearching = searchController.text.isNotEmpty;
                      final users = isSearching ? chatProvider.searchedUsers : profileProvider.followingList;
                      final isLoading = isSearching ? chatProvider.isLoading : profileProvider.isLoading;

                      if (isLoading && users.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (users.isEmpty) {
                        return Center(
                          child: Text(
                            isSearching ? "No users found" : "You are not following anyone yet",
                            style: text14(color: Colors.grey),
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final item = users[index];
                          
                          // Handle different model types
                          String name = 'Unknown';
                          String username = '';
                          String? image;
                          String id = '';

                          if (item is PartnerModel) {
                            name = item.name ?? 'Unknown';
                            username = item.username ?? '';
                            image = item.profileImage;
                            id = item.sId ?? item.id ?? '';
                          } else if (item is UserModel) {
                            name = item.name ?? 'Unknown';
                            username = item.username ?? '';
                            image = item.profileImage;
                            id = item.id ?? '';
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundImage: image != null && image.isNotEmpty
                                  ? NetworkImage(image)
                                  : null,
                              child: image == null || image.isEmpty
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                            title: Text(name),
                            subtitle: Text(username),
                            onTap: () async {
                              final convId = await chatProvider.createConversation(id);
                              if (convId != null && context.mounted) {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      conversationId: convId,
                                      partnerId: id,
                                      name: name,
                                      username: username,
                                      image: image ?? '',
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          "Messages",
          style: text20(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CallHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add_rounded, color: Colors.black),
            onPressed: () => _showUserSelection(context),
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoading && chatProvider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (chatProvider.error != null && chatProvider.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Error: ${chatProvider.error}"),
                  ElevatedButton(
                    onPressed: () => chatProvider.fetchConversations(),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          final conversations = chatProvider.filteredConversations;

          return RefreshIndicator(
            onRefresh: () async {
              _inboxSearchController.clear();
              chatProvider.setInboxSearchQuery('');
              await chatProvider.fetchConversations();
            },
            child: Column(
              children: [
                // Search Bar - ALWAYS VISIBLE
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _inboxSearchController,
                      onChanged: (value) {
                        chatProvider.setInboxSearchQuery(value);
                        setState(() {}); // Force local rebuild for suffix icon
                      },
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                        suffixIcon: _inboxSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                                onPressed: () {
                                  _inboxSearchController.clear();
                                  chatProvider.setInboxSearchQuery('');
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                
                if (conversations.isEmpty)
                  Expanded(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Text(
                            chatProvider.conversations.isEmpty 
                              ? "No conversations yet" 
                              : "No matching conversations found",
                            style: text16(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Active Now (Optional Instagram feature)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final chat = conversations[index];
                        if (chat.partner?.isOnline != true) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundImage: chat.partner?.profileImage != null && chat.partner!.profileImage!.isNotEmpty
                                        ? NetworkImage(chat.partner!.profileImage!)
                                        : null,
                                    child: chat.partner?.profileImage == null || chat.partner!.profileImage!.isEmpty
                                        ? const Icon(Icons.person, size: 30)
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 15,
                                      height: 15,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        border: Border.all(color: Colors.white, width: 2),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (chat.partner?.name ?? '').split(' ')[0],
                                style: text12(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(height: 1),

                  // Chat List
                  Expanded(
                    child: ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final chat = conversations[index];
                        final unreadCount = chat.unreadCount ?? 0;
                        return ListTile(
                          onTap: () {
                            if (unreadCount > 0) {
                              chatProvider.markAsRead(chat.sId!);
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  conversationId: chat.sId!,
                                  partnerId: chat.partner?.sId ?? chat.partner?.id ?? '',
                                  name: chat.partner?.name ?? '',
                                  username: chat.partner?.username ?? '',
                                  image: chat.partner?.profileImage ?? '',
                                ),
                              ),
                            );
                          },
                          onLongPress: () {
                            _showConversationOptions(context, chat, chatProvider);
                          },
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: chat.partner?.profileImage != null && chat.partner!.profileImage!.isNotEmpty
                                    ? NetworkImage(chat.partner!.profileImage!)
                                    : null,
                                child: chat.partner?.profileImage == null || chat.partner!.profileImage!.isEmpty
                                    ? const Icon(Icons.person, size: 25)
                                    : null,
                              ),
                              if (chat.isPinned == true)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.push_pin, color: Colors.white, size: 10),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            chat.partner?.name ?? 'Unknown',
                            style: text16(fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500),
                          ),
                          subtitle: Text(
                            chat.lastMessage?.text ?? 'No messages',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text14(
                              color: unreadCount > 0 ? Colors.black : Colors.grey,
                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(chat.lastMessageAt),
                                style: text12(color: Colors.grey),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showConversationOptions(BuildContext context, ConversationModel chat, ChatProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(chat.isPinned == true ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(chat.isPinned == true ? "Unpin Chat" : "Pin Chat"),
              onTap: () {
                provider.togglePin(chat.sId!);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Delete Chat", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteChatConfirm(context, chat, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteChatConfirm(BuildContext context, ConversationModel chat, ChatProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Chat?"),
        content: const Text("This will permanently delete this conversation and all its messages."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              provider.clearChat(chat.sId!);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
