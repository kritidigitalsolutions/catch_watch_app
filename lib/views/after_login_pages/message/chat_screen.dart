import 'package:catch_watch/models/chat_model.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/view_model/after_login_provider/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'chat_details_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String partnerId;
  final String name;
  final String username;
  final String image;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.partnerId,
    required this.name,
    required this.username,
    required this.image,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.setActiveConversation(widget.conversationId);
      chatProvider.fetchMessages(widget.conversationId);
      chatProvider.fetchUserStatus(widget.partnerId);
      chatProvider.fetchBlockedUsers();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ChatProvider>(context, listen: false).setActiveConversation(null);
      }
    });
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final success = await Provider.of<ChatProvider>(context, listen: false).sendMessage(
        conversationId: widget.conversationId,
        messageType: 'text',
        text: text,
      );
      if (success) {
        _messageController.clear();
        _scrollToBottom();
      }
    }
  }

  void _pickAndSendImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    
    if (pickedFile != null && mounted) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      // Show simple loading overlay or toast if needed
      final mediaUrl = await chatProvider.uploadAttachment(File(pickedFile.path));
      
      if (mediaUrl != null) {
        await chatProvider.sendMessage(
          conversationId: widget.conversationId,
          messageType: 'image',
          mediaUrl: mediaUrl,
        );
        _scrollToBottom();
      }
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleCall(bool isVideo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${isVideo ? 'Video' : 'Audio'} call feature coming soon!"),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // Reversed list
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatLastSeen(String lastSeenIso) {
    try {
      DateTime lastSeen = DateTime.parse(lastSeenIso).toLocal();
      DateTime now = DateTime.now();
      Duration diff = now.difference(lastSeen);

      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      if (diff.inDays < 7) return DateFormat('EEE, hh:mm a').format(lastSeen);
      return DateFormat('dd MMM, hh:mm a').format(lastSeen);
    } catch (e) {
      return "Offline";
    }
  }

  void _showMessageActions(MessageModel message) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUserId = HiveService.userId;
    final bool isMe = message.sender?.id == currentUserId || message.sender?.sId == currentUserId;

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
              _actionTile(Icons.reply_all_rounded, "Reply", () {
                Navigator.pop(context);
                // Implement reply logic
              }),
              _actionTile(Icons.copy, "Copy", () {
                Navigator.pop(context);
                // Implement copy logic
              }),
              if (message.messageType == 'text' && isMe)
                _actionTile(Icons.edit_outlined, "Edit", () {
                  Navigator.pop(context);
                  _showEditDialog(message);
                }),
              _actionTile(Icons.delete_outline, "Delete for me", () {
                chatProvider.deleteMessage(widget.conversationId, message.sId!);
                Navigator.pop(context);
              }, color: Colors.red),
              if (isMe)
                _actionTile(Icons.remove_circle_outline, "Unsend for everyone", () {
                  chatProvider.unsendMessage(widget.conversationId, message.sId!);
                  Navigator.pop(context);
                }, color: Colors.red),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(MessageModel message) {
    final TextEditingController editController = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Message"),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter new message"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                Provider.of<ChatProvider>(context, listen: false).editMessage(
                  widget.conversationId,
                  message.sId!,
                  editController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showSearchUI() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final TextEditingController searchController = TextEditingController();
    List<MessageModel> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
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
                      child: Text("Search in Chat", style: text18(fontWeight: FontWeight.bold)),
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
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Search messages...',
                            prefixIcon: Icon(Icons.search, size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: (value) async {
                            if (value.trim().isEmpty) return;
                            setModalState(() => isSearching = true);
                            final results = await chatProvider.searchInMessages(
                              value.trim(),
                              conversationId: widget.conversationId,
                            );
                            setModalState(() {
                              searchResults = results;
                              isSearching = false;
                            });
                          },
                        ),
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: isSearching
                          ? const Center(child: CircularProgressIndicator())
                          : searchResults.isEmpty
                              ? Center(
                                  child: Text(
                                    searchController.text.isEmpty
                                        ? "Enter text to search"
                                        : "No messages found",
                                    style: text14(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: searchResults.length,
                                  itemBuilder: (context, index) {
                                    final msg = searchResults[index];
                                    return ListTile(
                                      title: Text(msg.text ?? ''),
                                      subtitle: Text(DateFormat('dd MMM, hh:mm a')
                                          .format(DateTime.parse(msg.createdAt!).toLocal())),
                                      onTap: () {
                                        Navigator.pop(context);
                                        // Ideally scroll to this message in main list
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
      },
    );
  }

  void _showChatOptions() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final isBlocked = chatProvider.isUserBlocked(widget.partnerId);
    final conv = chatProvider.conversations.firstWhere(
      (c) => c.sId == widget.conversationId,
      orElse: () => ConversationModel(),
    );
    final isPinned = conv.isPinned ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),
            _actionTile(Icons.search, "Search Chat", () {
              Navigator.pop(context);
              _showSearchUI();
            }),
            _actionTile(
              isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              isPinned ? "Unpin Chat" : "Pin Chat",
              () {
                chatProvider.togglePin(widget.conversationId);
                Navigator.pop(context);
              },
            ),
            _actionTile(Icons.delete_outline, "Clear Chat", () {
              Navigator.pop(context);
              _showClearChatConfirm();
            }, color: Colors.red),
            _actionTile(
              isBlocked ? Icons.lock_open : Icons.block,
              isBlocked ? "Unblock User" : "Block User",
              () {
                Navigator.pop(context);
                if (isBlocked) {
                  chatProvider.unblockUser(widget.partnerId);
                } else {
                  _showBlockDialog(context);
                }
              },
              color: Colors.red,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Block ${widget.name}?"),
        content: const Text("They won't be able to message you or find your profile on Catch Watch."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Provider.of<ChatProvider>(context, listen: false).blockUser(widget.partnerId);
              Navigator.pop(context);
            },
            child: const Text("Block", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearChatConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Chat?"),
        content: const Text("This will delete all messages in this conversation."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final provider = Provider.of<ChatProvider>(context, listen: false);
              final navigator = Navigator.of(context);
              bool success = await provider.clearChat(widget.conversationId);
              if (success && mounted) {
                navigator.pop(); // Close dialog
                navigator.pop(); // Go back to message list
              }
            },
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black),
      title: Text(label, style: TextStyle(color: color ?? Colors.black)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = HiveService.userId;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailsScreen(
                  partnerId: widget.partnerId,
                  name: widget.name,
                  username: widget.username,
                  image: widget.image,
                ),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(widget.image),
              ),
              const SizedBox(width: 10),
              Consumer<ChatProvider>(
                builder: (context, provider, child) {
                  final status = provider.currentUserStatus;
                  String statusText = "Offline";
                  Color statusColor = Colors.grey;

                  if (status != null) {
                    if (status.isOnline == true) {
                      statusText = "Online";
                      statusColor = Colors.green;
                    } else if (status.lastSeen != null) {
                      statusText = _formatLastSeen(status.lastSeen!);
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.name, style: text16(fontWeight: FontWeight.bold)),
                      Text(statusText, style: text12(color: statusColor)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () => _handleCall(false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () => _handleCall(true),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isMessagesLoading && chatProvider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = chatProvider.messages;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  reverse: true, // Show latest messages at the bottom
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isMe = message.sender?.id == currentUserId || message.sender?.sId == currentUserId;
                    
                    if (message.isUnsent == true) {
                      return Align(
                        alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            isMe ? "You unsent a message" : "This message was unsent",
                            style: text12(color: Colors.grey),
                          ),
                        ),
                      );
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                      child: GestureDetector(
                        onLongPress: () => _showMessageActions(message),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.primary : Colors.grey[200],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(isMe ? 0 : 20),
                                  bottomRight: Radius.circular(isMe ? 20 : 0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.start,
                                children: [
                                  if (message.messageType == 'image' && message.mediaUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          message.mediaUrl!,
                                          width: 200,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              width: 200,
                                              height: 150,
                                              color: Colors.grey[300],
                                              child: const Center(child: CircularProgressIndicator()),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 200,
                                            height: 150,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.broken_image, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (message.text != null && message.text!.isNotEmpty)
                                    Text(
                                      message.text!,
                                      style: text14(color: isMe ? Colors.white : Colors.black),
                                    ),
                                  if (message.isEdited == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        "edited",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe ? Colors.white70 : Colors.black54,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isMe)
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 4),
                                child: Text(
                                  message.status == 'READ' ? 'Seen' : 'Sent',
                                  style: text10(color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Bottom Input
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              final isBlocked = chatProvider.isUserBlocked(widget.partnerId);

              if (isBlocked) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "You have blocked this user",
                          style: text14(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => chatProvider.unblockUser(widget.partnerId),
                          child: Text(
                            "Tap to Unblock",
                            style: text14(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: _showMediaPicker,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Message...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _messageController,
                        builder: (context, value, child) {
                          return TextButton(
                            onPressed: value.text.isEmpty ? null : _sendMessage,
                            child: Text(
                              "Send",
                              style: text16(
                                color: value.text.isEmpty ? Colors.grey : AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
