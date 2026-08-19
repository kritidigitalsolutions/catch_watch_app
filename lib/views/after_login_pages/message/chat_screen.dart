import 'dart:async';
import 'dart:io';
import 'package:catch_watch/data/network/notification_service.dart';
import 'package:catch_watch/models/chat_model.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/call_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'chat_details_screen.dart';
import 'media_preview_screen.dart';

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
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  Timer? _statusTimer;
  String? _highlightedMessageId;
  List<MessageModel> _searchResults = [];
  int _searchIndex = -1;
  bool _isSearchNavActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.activeChatId = widget.conversationId;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.setActiveConversation(widget.conversationId, widget.partnerId);
      chatProvider.fetchMessages(widget.conversationId);

      chatProvider.fetchPinnedMessages(widget.conversationId);
      chatProvider.fetchUserStatus(widget.partnerId);
      chatProvider.fetchBlockedUsers();
    });
  }

  @override
  void dispose() {
    NotificationService.activeChatId = null;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatProvider.setActiveConversation(null);
      chatProvider.clearReplyingMessage();
    });
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final success = await chatProvider.sendMessage(
        conversationId: widget.conversationId,
        messageType: 'text',
        text: text,
      );
      if (success) {
        _messageController.clear();
        _scrollToBottom();
      } else if (chatProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(chatProvider.error!)),
        );
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
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    callProvider.startCall(
      widget.partnerId, 
      isVideo ? 'video' : 'audio',
      partnerName: widget.name,
      partnerImage: widget.image,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (_itemScrollController.isAttached && chatProvider.messages.isNotEmpty) {
        _itemScrollController.scrollTo(
          index: 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToOriginalMessage(String replyToId) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final index = chatProvider.messages.indexWhere((m) => m.sId == replyToId);
    
    if (index != -1 && _itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      
      setState(() {
        _highlightedMessageId = replyToId;
      });
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Original message not found in local history")),
      );
    }
  }

  void _scrollToSearchMessage(int index) {
    if (index < 0 || index >= _searchResults.length) return;
    
    final messageId = _searchResults[index].sId;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // Find index in current messages list
    final listIndex = chatProvider.messages.indexWhere((m) => m.sId == messageId);
    
    if (listIndex != -1 && _itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: listIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      
      setState(() {
        _searchIndex = index;
        _highlightedMessageId = messageId;
      });
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message not found in local history")),
      );
    }
  }

  MessageModel? _getRepliedMessage(String? replyToId) {
    if (replyToId == null) return null;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      return chatProvider.messages.firstWhere((m) => m.sId == replyToId);
    } catch (_) {
      return null;
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
    final bool isMe = (currentUserId != null && (message.sender?.sId == currentUserId || message.sender?.id == currentUserId)) ||
                     (message.sender != null && message.sender?.sId != widget.partnerId && message.sender?.id != widget.partnerId);

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
              _actionTile(Icons.reply_rounded, "Reply", () {
                Navigator.pop(context);
                chatProvider.setReplyingMessage(message);
              }),
              _actionTile(Icons.forward_rounded, "Forward", () {
                Navigator.pop(context);
                _showForwardSelectionDialog(message);
              }),
              _actionTile(Icons.add_reaction_outlined, "React", () {
                Navigator.pop(context);
                _showReactionPicker(message);
              }),
              _actionTile(
                message.isPinned == true ? Icons.push_pin : Icons.push_pin_outlined, 
                message.isPinned == true ? "Unpin" : "Pin", 
                () {
                  Navigator.pop(context);
                  chatProvider.pinMessage(widget.conversationId, message.sId!);
                }
              ),
              if (message.cipherText != null)
                _actionTile(Icons.enhanced_encryption_outlined, "Show Encrypted", () {
                  Navigator.pop(context);
                  _showEncryptedDialog(message);
                }),
              _actionTile(Icons.copy, "Copy", () {

                Navigator.pop(context);
                // Implement copy logic
              }),
              if (message.messageType == 'text' && isMe && 
                  message.createdAt != null && 
                  DateTime.now().difference(DateTime.parse(message.createdAt!)).inMinutes <= 5)
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

  void _showForwardSelectionDialog(MessageModel message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return _ForwardRecipientSelector(message: message);
      },
    );
  }

  void _showReactionPicker(MessageModel message) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final List<String> emojis = ["❤️", "👍", "🔥", "😂", "😮", "😢", "🙏"];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                chatProvider.reactToMessage(message.sId!, emoji);
                Navigator.pop(context);
              },
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
            );
          }).toList(),
        ),
      ),
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

  void _showEncryptedDialog(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            const Text("Encrypted Content"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Plain Text:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(message.text ?? ""),
              const SizedBox(height: 16),
              const Text("Ciphertext (from Server):", style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message.cipherText ?? "Not available",
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "This message is secured with AES-256-GCM encryption. Only you and the recipient can read its contents.",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
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
                          onChanged: (value) async {
                            if (value.trim().isEmpty) {
                              setModalState(() {
                                searchResults = [];
                              });
                              return;
                            }
                            
                            // Simple debounce or direct call
                            // For local search, direct call is fine. 
                            // If backend is fast, we can call directly.
                            final results = await chatProvider.searchInMessages(
                              value.trim(),
                              conversationId: widget.conversationId,
                            );
                            setModalState(() {
                              searchResults = results;
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
                                        setState(() {
                                          _searchResults = searchResults;
                                          _searchIndex = index;
                                          _isSearchNavActive = true;
                                        });
                                        Navigator.pop(context);
                                        _scrollToSearchMessage(index);
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
    final blockedByMe = chatProvider.isBlockedByMe(widget.partnerId);
    final partnerBlockedMe = chatProvider.isPartnerBlockedMe(widget.partnerId);
    
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
            _actionTile(Icons.delete_outline, "Delete Chat", () {
              Navigator.pop(context);
              _showDeleteChatConfirm();
            }, color: Colors.red),
            
            if (blockedByMe)
              _actionTile(
                Icons.lock_open,
                "Unblock User",
                () {
                  Navigator.pop(context);
                  _showUnblockConfirmation(context, chatProvider);
                },
                color: Colors.red,
              )
            else
              _actionTile(
                Icons.block,
                "Block User",
                () {
                  Navigator.pop(context);
                  _showBlockDialog(context);
                },
                color: Colors.red,
              ),
            const SizedBox(height: 20),
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
        content: Text("Do you want to unblock ${widget.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              provider.unblockUser(widget.partnerId);
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

  void _showDeleteChatConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Chat?"),
        content: const Text("This will permanently delete this conversation and all its messages."),
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
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionsDisplay(List<ReactionModel> reactions, bool isMe) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Group reactions by emoji
    final Map<String, int> emojiCounts = {};
    for (var r in reactions) {
      if (r.emoji != null) {
        emojiCounts[r.emoji!] = (emojiCounts[r.emoji!] ?? 0) + 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Wrap(
        spacing: 4,
        children: emojiCounts.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 12)),
                if (entry.value > 1) ...[
                  const SizedBox(width: 2),
                  Text(
                    entry.value.toString(),
                    style: text10(color: Colors.grey[700] ?? Colors.grey),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
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
                  conversationId: widget.conversationId,
                ),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.image != null && widget.image.isNotEmpty
                    ? NetworkImage(widget.image)
                    : null,
                child: widget.image == null || widget.image.isEmpty
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Consumer<ChatProvider>(
                builder: (context, provider, child) {
                  final isBlocked = provider.isUserBlocked(widget.partnerId);
                  if (isBlocked) return const SizedBox.shrink();

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
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              final pinned = chatProvider.pinnedMessages;
              if (pinned.isEmpty) return const SizedBox.shrink();

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _scrollToOriginalMessage(pinned.first.sId!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pinned.first.sender?.name ?? "Pinned Message",
                              style: text10(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            Text(
                              pinned.first.text ?? (pinned.first.messageType == 'image' ? 'Photo' : 'Pinned Message'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text12(fontWeight: FontWeight.w400),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (pinned.length > 1)
                      Text(
                        "+${pinned.length - 1}",
                        style: text10(color: Colors.grey),
                      ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isMessagesLoading && chatProvider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Create a local copy of the messages list to avoid modification during build
                final messages = List<MessageModel>.from(chatProvider.messages);
                
                if (messages.isEmpty) {
                  return const Center(child: Text("No messages yet. Say hi!"));
                }

                debugPrint('ChatScreen: Rendering ${messages.length} messages. First text: ${messages.first.text}');

                // Find indices for status display - COMPUTE ONCE per build
                int? lastMyMessageIndex;
                int? lastReadMyMessageIndex;

                for (int i = 0; i < messages.length; i++) {
                  final msg = messages[i];
                  final bool isMe = (currentUserId != null && (msg.sender?.sId == currentUserId || msg.sender?.id == currentUserId)) ||
                                   (msg.sender != null && msg.sender?.sId != widget.partnerId && msg.sender?.id != widget.partnerId);
                  
                  if (isMe) {
                    if (lastMyMessageIndex == null) {
                      lastMyMessageIndex = i;
                    }
                    if (msg.status == 'READ' && lastReadMyMessageIndex == null) {
                      lastReadMyMessageIndex = i;
                    }
                    if (lastMyMessageIndex != null && lastReadMyMessageIndex != null) break;
                  }
                }

                return ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  padding: const EdgeInsets.all(16),
                  reverse: true, // Show latest messages at the bottom
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    if (index >= messages.length) return const SizedBox.shrink();
                    final message = messages[index];
                    final bool isMe = (currentUserId != null && (message.sender?.sId == currentUserId || message.sender?.id == currentUserId)) ||
                                     (message.sender != null && message.sender?.sId != widget.partnerId && message.sender?.id != widget.partnerId);
                    
                    final bool isHighlighted = _highlightedMessageId == message.sId;
                    
                    // Status display logic
                    bool shouldShowStatus = false;
                    if (isMe) {
                      if (index == lastMyMessageIndex) {
                        shouldShowStatus = true;
                      } else if (index == lastReadMyMessageIndex && lastReadMyMessageIndex != lastMyMessageIndex) {
                        shouldShowStatus = true;
                      }
                    }

                    if (message.isUnsent == true) {
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => _showMessageActions(message),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isHighlighted 
                                    ? Colors.yellow.withOpacity(0.3)
                                    : (isMe ? AppColors.primary : Colors.grey[200]),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(isMe ? 20 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 20),
                                ),
                                border: isHighlighted ? Border.all(color: Colors.yellow, width: 2) : null,
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (message.isForwarded == true)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.forward_rounded,
                                            size: 12,
                                            color: isMe ? Colors.white70 : Colors.black54,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Forwarded",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontStyle: FontStyle.italic,
                                              color: isHighlighted ? Colors.black54 : (isMe ? Colors.white70 : Colors.black54),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (message.replyTo != null)
                                    GestureDetector(
                                      onTap: () => _scrollToOriginalMessage(message.replyTo!),
                                      child: Builder(
                                        builder: (context) {
                                          final repliedMsg = _getRepliedMessage(message.replyTo);
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.05),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border(
                                                left: BorderSide(
                                                  color: isMe ? Colors.white : AppColors.primary,
                                                  width: 3,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  repliedMsg?.sender?.name ?? "Message",
                                                  style: text10(
                                                    fontWeight: FontWeight.bold,
                                                    color: isHighlighted ? AppColors.primary : (isMe ? Colors.white : AppColors.primary)
                                                  ),
                                                ),
                                                Text(
                                                  repliedMsg?.text ?? 
                                                  (repliedMsg?.messageType == 'image' ? 'Photo' : 'Replying to a message'),
                                                  style: text12(color: isHighlighted ? Colors.black87 : (isMe ? Colors.white70 : Colors.black87)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      ),
                                    ),
                                  if ((message.messageType == 'image' || message.messageType == 'gif') && 
                                      message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => MediaPreviewScreen(
                                              url: message.mediaUrl!,
                                              type: 'image',
                                            ),
                                          ),
                                        ),
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
                                    ),
                                  if (message.messageType == 'video' && 
                                      message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => MediaPreviewScreen(
                                              url: message.mediaUrl!,
                                              type: 'video',
                                            ),
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            width: 200,
                                            height: 150,
                                            color: Colors.black87,
                                            child: const Center(
                                              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (message.text != null && message.text!.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (message.isDecrypted)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 4, bottom: 2),
                                            child: Icon(
                                              Icons.lock_outline,
                                              size: 10,
                                              color: isHighlighted ? Colors.black54 : (isMe ? Colors.white70 : Colors.black54),
                                            ),
                                          ),
                                        Flexible(
                                          child: Text(
                                            message.text!,
                                            style: text14(color: isHighlighted ? Colors.black : (isMe ? Colors.white : Colors.black)),
                                          ),
                                        ),
                                      ],
                                    ),

                                  if (message.isPinned == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Icon(
                                        Icons.push_pin,
                                        size: 12,
                                        color: isMe ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  if (message.isEdited == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        "edited",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isHighlighted ? Colors.black54 : (isMe ? Colors.white70 : Colors.black54),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (message.reactions != null && message.reactions!.isNotEmpty)
                              _buildReactionsDisplay(message.reactions as List<ReactionModel>, isMe),
                            if (shouldShowStatus)
                              Padding(
                                padding: const EdgeInsets.only(right: 4, bottom: 4),
                                child: Text(
                                  message.status == 'READ' 
                                      ? 'Seen' 
                                      : (message.status == 'DELIVERED' ? 'Delivered' : 'Sent'),
                                  style: text10(color: message.status == 'READ' ? AppColors.primary : Colors.grey),
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
          _buildSearchNavOverlay(),
          // Bottom Input
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              final isBlocked = chatProvider.isUserBlocked(widget.partnerId);

              if (isBlocked) {
                final blockedByMe = chatProvider.isBlockedByMe(widget.partnerId);
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
                          blockedByMe ? "You have blocked this user" : "This user has blocked you",
                          style: text14(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        if (blockedByMe) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showUnblockConfirmation(context, chatProvider),
                            child: Text(
                              "Tap to Unblock",
                              style: text14(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (chatProvider.replyingToMessage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.reply_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Replying to ${chatProvider.replyingToMessage!.sender?.name ?? 'Message'}",
                                  style: text12(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                Text(
                                  chatProvider.replyingToMessage!.text ?? 
                                  (chatProvider.replyingToMessage!.messageType == 'image' ? 'Photo' : 'Media'),
                                  style: text12(color: AppColors.grey600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                            onPressed: () => chatProvider.clearReplyingMessage(),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Attachment Button
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                            onPressed: _showMediaPicker,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          
                          // Input Field Container
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _messageController,
                                      maxLines: 4,
                                      minLines: 1,
                                      decoration: const InputDecoration(
                                        hintText: 'Message...',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Send Button
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _messageController,
                            builder: (context, value, child) {
                              final bool hasText = value.text.trim().isNotEmpty;
                              return Container(
                                margin: const EdgeInsets.only(left: 4, bottom: 4),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: hasText ? AppColors.primary : Colors.grey[300],
                                  child: IconButton(
                                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                    onPressed: hasText ? _sendMessage : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  Widget _buildSearchNavOverlay() {
    if (!_isSearchNavActive || _searchResults.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Text(
            "${_searchIndex + 1} of ${_searchResults.length}",
            style: text14(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, color: AppColors.primary),
            onPressed: _searchIndex > 0 
                ? () => _scrollToSearchMessage(_searchIndex - 1) 
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
            onPressed: _searchIndex < _searchResults.length - 1 
                ? () => _scrollToSearchMessage(_searchIndex + 1) 
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () {
              setState(() {
                _isSearchNavActive = false;
                _searchResults = [];
                _searchIndex = -1;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _ForwardRecipientSelector extends StatefulWidget {
  final MessageModel message;
  const _ForwardRecipientSelector({required this.message});

  @override
  State<_ForwardRecipientSelector> createState() => _ForwardRecipientSelectorState();
}

class _ForwardRecipientSelectorState extends State<_ForwardRecipientSelector> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false).searchUsers('');
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
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
              child: Text("Forward to...", style: text18(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => Provider.of<ChatProvider>(context, listen: false).searchUsers(val),
                decoration: InputDecoration(
                  hintText: "Search users",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = provider.searchedUsers;
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.profileImage != null ? NetworkImage(user.profileImage!) : null,
                          child: user.profileImage == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(user.name ?? 'User'),
                        subtitle: Text("@${user.username ?? ''}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                          onPressed: () async {
                            final success = await provider.forwardMessage(
                              recipientId: user.sId!,
                              originalMessage: widget.message,
                            );
                            if (success && mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Message forwarded")),
                              );
                            }
                          },
                        ),
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
  }
}
