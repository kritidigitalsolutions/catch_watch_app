import 'package:flutter/material.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'chat_screen.dart';

class MessageListScreen extends StatefulWidget {
  const MessageListScreen({super.key});

  @override
  State<MessageListScreen> createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  final List<Map<String, dynamic>> _mockChats = [
    {
      'name': 'Rahul Sharma',
      'username': 'rahul_s',
      'lastMessage': 'Bhai movie dekhi?',
      'time': '2m',
      'unread': 2,
      'isOnline': true,
      'image': 'https://randomuser.me/api/portraits/men/1.jpg'
    },
    {
      'name': 'Sneha Kapoor',
      'username': 'sneha_k',
      'lastMessage': 'The new reel is awesome!',
      'time': '15m',
      'unread': 0,
      'isOnline': false,
      'image': 'https://randomuser.me/api/portraits/women/2.jpg'
    },
    {
      'name': 'Amit Verma',
      'username': 'amit_v',
      'lastMessage': 'Sent a reel',
      'time': '1h',
      'unread': 0,
      'isOnline': true,
      'image': 'https://randomuser.me/api/portraits/men/3.jpg'
    },
    {
      'name': 'Priya Singh',
      'username': 'priya_s',
      'lastMessage': 'Let\'s watch together tonight.',
      'time': '3h',
      'unread': 1,
      'isOnline': false,
      'image': 'https://randomuser.me/api/portraits/women/4.jpg'
    },
    {
      'name': 'Vikram Mehra',
      'username': 'vikram_m',
      'lastMessage': 'Reacted ❤️ to your message',
      'time': '5h',
      'unread': 0,
      'isOnline': false,
      'image': 'https://randomuser.me/api/portraits/men/5.jpg'
    },
  ];

  void _showUserSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("New Message", style: text18(fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _mockChats.length,
                  itemBuilder: (context, index) {
                    final user = _mockChats[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(user['image']),
                      ),
                      title: Text(user['name']),
                      subtitle: Text("@${user['username']}"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              name: user['name'],
                              username: user['username'],
                              image: user['image'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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
            icon: const Icon(Icons.group_add_rounded, color: Colors.black),
            onPressed: () => _showUserSelection(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          
          // Stories/Active Now (Optional Instagram feature)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _mockChats.length,
              itemBuilder: (context, index) {
                final chat = _mockChats[index];
                if (!chat['isOnline']) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(chat['image']),
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
                        chat['name'].split(' ')[0],
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
              itemCount: _mockChats.length,
              itemBuilder: (context, index) {
                final chat = _mockChats[index];
                return ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          name: chat['name'],
                          username: chat['username'] ?? '',
                          image: chat['image'],
                        ),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage(chat['image']),
                  ),
                  title: Text(
                    chat['name'],
                    style: text16(fontWeight: chat['unread'] > 0 ? FontWeight.bold : FontWeight.w500),
                  ),
                  subtitle: Text(
                    chat['lastMessage'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text14(
                      color: chat['unread'] > 0 ? Colors.black : Colors.grey,
                      fontWeight: chat['unread'] > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        chat['time'],
                        style: text12(color: Colors.grey),
                      ),
                      if (chat['unread'] > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chat['unread'].toString(),
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
      ),
    );
  }
}
