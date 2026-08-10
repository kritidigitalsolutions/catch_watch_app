import 'dart:convert';
import 'dart:io';

import 'package:catch_watch/data/network/notification_service.dart';
import 'package:catch_watch/data/network/socket_service.dart';
import 'package:catch_watch/models/chat_model.dart';
import 'package:catch_watch/repository/chat_repository.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:dio/dio.dart' as dio;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _chatRepository = ChatRepository();
  final SocketService _socketService = SocketService();

  List<ConversationModel> _conversations = [];
  List<MessageModel> _messages = [];
  List<PartnerModel> _searchedUsers = [];
  bool _isLoading = false;
  bool _isMessagesLoading = false;
  String? _error;
  PaginationModel? _pagination;
  UserStatus? _currentUserStatus;
  Set<String> _blockedUserIds = {};
  String? _activeConversationId;
  MessageModel? _replyingToMessage;

  List<ConversationModel> get conversations => _conversations;
  List<MessageModel> get messages => _messages;
  List<PartnerModel> get searchedUsers => _searchedUsers;
  bool get isLoading => _isLoading;
  bool get isMessagesLoading => _isMessagesLoading;
  String? get error => _error;
  PaginationModel? get pagination => _pagination;
  UserStatus? get currentUserStatus => _currentUserStatus;
  Set<String> get blockedUserIds => _blockedUserIds;
  MessageModel? get replyingToMessage => _replyingToMessage;

  bool isUserBlocked(String userId) => _blockedUserIds.contains(userId);

  void setReplyingMessage(MessageModel? message) {
    _replyingToMessage = message;
    notifyListeners();
  }

  void clearReplyingMessage() {
    _replyingToMessage = null;
    notifyListeners();
  }

  ChatProvider() {
    _initSocket();
    _initNotificationListener();
  }

  void initSocket() {
    _socketService.disconnect();
    _socketService.connect();
  }

  void _initSocket() {
    _socketService.connect();
    _socketService.messageStream.listen((data) {
      debugPrint('Socket Event Received: ${data['event']}');
      _handleSocketMessage(data);
    }, onError: (e) {
      debugPrint('Socket Stream Error: $e');
    });
  }

  void _initNotificationListener() {
    NotificationService.foregroundMessageStream.listen((message) {
      debugPrint('FCM Foreground Message Received in ChatProvider');
      _handleForegroundNotification(message);
    });
  }

  void _handleForegroundNotification(RemoteMessage message) {
    try {
      final type = message.data['type'];
      final conversationId = message.data['conversationId'];
      
      if (type == 'CHAT_MESSAGE' || conversationId != null) {
        debugPrint('Processing foreground notification: Type=$type, Conv=$conversationId');

        if (!_socketService.isConnected) {
          if (type == 'READ_RECEIPT' || type == 'MESSAGE_READ') {
            _onMessageRead(message.data);
          } else if (type == 'DELIVERED_RECEIPT' || type == 'MESSAGE_DELIVERED') {
            _onMessageDelivered(message.data);
          } else {
            // New message fallback
            final Map<String, dynamic> payload = Map<String, dynamic>.from(message.data);
            if (payload['text'] == null && payload['body'] == null && payload['message'] == null) {
              if (message.notification != null) {
                payload['text'] = message.notification!.body;
              }
            }
            _onNewMessage(payload);
          }
          
          // Try to reconnect
          _socketService.connect();
        }
      }
    } catch (e) {
      debugPrint('Error handling foreground notification in ChatProvider: $e');
    }
  }

  void _handleSocketMessage(Map<String, dynamic> data) {
    final event = data['event'];
    final payload = data['data'];

    switch (event) {
      case 'new_message':
      case 'receive_message':
      case 'message':
        _onNewMessage(payload);
        break;
      case 'status_update':
      case 'user_status':
        _onStatusUpdate(payload);
        break;
      case 'message_read':
      case 'read_receipt':
      case 'READ_RECEIPT':
        _onMessageRead(payload);
        break;
      case 'message_delivered':
      case 'delivered_receipt':
      case 'DELIVERED_RECEIPT':
        _onMessageDelivered(payload);
        break;
      case 'user_blocked':
        _onUserBlocked(payload);
        break;
      case 'message_reaction':
      case 'new_reaction':
      case 'reaction':
        _onMessageReaction(payload);
        break;
      default:
        debugPrint('Unhandled Socket Event: $event');
    }
  }

  void _onNewMessage(dynamic payload) {
    try {
      debugPrint('Processing New Message Payload: $payload');
      final MessageModel newMessage;
      
      if (payload is Map<String, dynamic> && payload.containsKey('_id')) {
        newMessage = MessageModel.fromJson(payload);
      } else {
        // Handle flat map from FCM (Map<String, String>)
        // Some backends might send JSON strings for nested objects
        dynamic senderData = payload['sender'];
        if (senderData is String && senderData.startsWith('{')) {
          try {
            senderData = jsonDecode(senderData);
          } catch (_) {}
        }

        newMessage = MessageModel(
          sId: payload['_id'] ?? payload['messageId'] ?? payload['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: payload['conversationId'],
          text: payload['text'] ?? payload['body'] ?? payload['message'] ?? '',
          messageType: payload['messageType'] ?? 'text',
          mediaUrl: payload['mediaUrl'],
          createdAt: payload['createdAt'] ?? DateTime.now().toIso8601String(),
          sender: senderData is Map 
            ? Sender.fromJson(Map<String, dynamic>.from(senderData))
            : Sender(
                sId: payload['senderId'] ?? payload['sender_id'],
                name: payload['senderName'] ?? payload['sender_name'],
                profileImage: payload['senderImage'] ?? payload['sender_image'],
              ),
          status: 'DELIVERED',
        );
      }

      final conversationId = newMessage.conversationId;
      debugPrint('Resolved Message: ID=${newMessage.sId}, Text=${newMessage.text}, Conv=${newMessage.conversationId}');
      
      if (conversationId == null) {
        debugPrint('Warning: New message has no conversationId');
        return;
      }

      // Update conversations list
      final convIndex = _conversations.indexWhere((c) => c.sId == conversationId);
      if (convIndex != -1) {
        _conversations[convIndex].lastMessage = newMessage;
        _conversations[convIndex].lastMessageAt = newMessage.createdAt;
        if (conversationId != _activeConversationId) {
          _conversations[convIndex].unreadCount = (_conversations[convIndex].unreadCount ?? 0) + 1;
        }
        _sortConversations();
      } else {
        fetchConversations(); // Fetch if new conversation started
      }

      // Update current message list if it's the active conversation
      if (conversationId == _activeConversationId) {
        debugPrint('Updating active conversation messages list');
        // Avoid duplicates if HTTP send also added it
        if (!_messages.any((m) => m.sId == newMessage.sId)) {
          _messages.insert(0, newMessage);
          debugPrint('Message inserted into list');
        } else {
          debugPrint('Message already exists in list, skipping insertion');
        }
      } else {
        debugPrint('Message is not for active conversation, skipping list update');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling new message socket event: $e');
    }
  }

  void _onStatusUpdate(dynamic payload) {
    try {
      final status = UserStatus.fromJson(payload);
      
      // Update partner status in conversations list
      bool changed = false;
      for (var conv in _conversations) {
        if (conv.partner?.sId == status.userId || conv.partner?.id == status.userId) {
          conv.partner?.isOnline = status.isOnline;
          conv.partner?.lastSeen = status.lastSeen;
          changed = true;
        }
      }

      if (_currentUserStatus?.userId == status.userId) {
        _currentUserStatus = status;
        changed = true;
      }
      
      if (changed) notifyListeners();
    } catch (e) {
      debugPrint('Error handling status update socket event: $e');
    }
  }

  void _onMessageRead(dynamic payload) {
    try {
      final conversationId = payload['conversationId'] ?? payload['conversation_id'];
      debugPrint('Message Read Event for Conversation: $conversationId (Active: $_activeConversationId)');
      
      if (conversationId == null) return;

      // Update in conversation list
      final convIndex = _conversations.indexWhere((c) => c.sId == conversationId);
      if (convIndex != -1) {
        _conversations[convIndex].unreadCount = 0;
        if (_conversations[convIndex].lastMessage != null) {
          _conversations[convIndex].lastMessage!.status = 'READ';
        }
      }

      if (conversationId == _activeConversationId) {
        debugPrint('Marking local messages as READ');
        bool changed = false;
        for (var msg in _messages) {
          // If we receive a read receipt for the conversation, all previous messages are read
          if (msg.status != 'READ') {
            msg.status = 'READ';
            changed = true;
          }
        }
        if (changed) notifyListeners();
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling message read event: $e');
    }
  }

  void _onMessageDelivered(dynamic payload) {
    try {
      final conversationId = payload['conversationId'] ?? payload['conversation_id'];
      final messageId = payload['messageId'] ?? payload['message_id'] ?? payload['_id'];
      
      debugPrint('Message Delivered Event for Conversation: $conversationId, Message: $messageId');

      if (conversationId == null) return;

      if (conversationId == _activeConversationId) {
        bool changed = false;
        if (messageId != null) {
          final index = _messages.indexWhere((m) => m.sId == messageId);
          if (index != -1 && _messages[index].status != 'READ') {
            _messages[index].status = 'DELIVERED';
            changed = true;
          }
        } else {
          // If no specific message ID, mark all 'SENT' as 'DELIVERED'
          for (var msg in _messages) {
            if (msg.status == 'SENT' || msg.status == null) {
              msg.status = 'DELIVERED';
              changed = true;
            }
          }
        }
        if (changed) notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling message delivered event: $e');
    }
  }

  void _onMessageReaction(dynamic payload) {
    try {
      final messageId = payload['messageId'];
      final reaction = ReactionModel.fromJson(payload['reaction'] ?? payload);
      
      final index = _messages.indexWhere((m) => m.sId == messageId);
      if (index != -1) {
        final reactions = _messages[index].reactions ?? [];
        // Remove old reaction from same user if exists
        reactions.removeWhere((r) => r.userId == reaction.userId);
        reactions.add(reaction);
        _messages[index].reactions = reactions;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error handling message reaction socket event: $e');
    }
  }

  void _onUserBlocked(dynamic payload) {
    final blockedUserId = payload['blockedUserId'];
    final blockerId = payload['blockerId'];
    final currentUserId = HiveService.userId;

    if (blockerId == currentUserId) {
      _blockedUserIds.add(blockedUserId);
    } else if (blockedUserId == currentUserId) {
      // Current user was blocked by someone
      // You might want to track who blocked you or just handle UI
    }
    notifyListeners();
  }

  void setActiveConversation(String? id) {
    _activeConversationId = id;
    NotificationService.activeChatId = id;
    if (id != null) {
      markAsRead(id);
    }
  }

  int get totalUnreadCount {
    int count = 0;
    for (var conv in _conversations) {
      count += conv.unreadCount ?? 0;
    }
    return count;
  }

  Future<void> fetchConversations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Ensure socket is connected when we start interacting with chat
    _socketService.connect();

    try {
      final response = await _chatRepository.fetchConversations();
      _conversations = response;
      // Sort: pinned first, then by last message time
      _sortConversations();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortConversations() {
    _conversations.sort((a, b) {
      if (a.isPinned == true && b.isPinned != true) return -1;
      if (a.isPinned != true && b.isPinned == true) return 1;
      
      DateTime timeA = DateTime.tryParse(a.lastMessageAt ?? '') ?? DateTime(2000);
      DateTime timeB = DateTime.tryParse(b.lastMessageAt ?? '') ?? DateTime(2000);
      return timeB.compareTo(timeA);
    });
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      await _chatRepository.markAsRead(conversationId);
      final index = _conversations.indexWhere((c) => c.sId == conversationId);
      if (index != -1) {
        _conversations[index].unreadCount = 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> togglePin(String conversationId) async {
    try {
      debugPrint('Toggling pin for: $conversationId');
      final response = await _chatRepository.togglePin(conversationId);
      debugPrint('Toggle pin response: $response');
      
      final index = _conversations.indexWhere((c) => c.sId == conversationId);
      if (index != -1) {
        _conversations[index].isPinned = !(_conversations[index].isPinned ?? false);
        _sortConversations();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling pin: $e');
    }
  }

  Future<bool> clearChat(String conversationId) async {
    try {
      await _chatRepository.clearChat(conversationId);
      _conversations.removeWhere((c) => c.sId == conversationId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error clearing chat: $e');
      return false;
    }
  }

  Future<String?> createConversation(String recipientId) async {
    try {
      final response = await _chatRepository.createConversation(recipientId);
      if (response['success'] == true) {
        await fetchConversations();
        return response['data']['_id'] ?? response['data']['id'];
      }
      return null;
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      return null;
    }
  }

  // Message Methods
  Future<void> fetchMessages(String conversationId, {int page = 1}) async {
    // Ensure socket is connected when we enter a conversation
    _socketService.connect();

    if (page == 1) {
      _messages = [];
      _isMessagesLoading = true;
      _pagination = null;
      notifyListeners();
    }

    try {
      final response = await _chatRepository.fetchMessages(conversationId, page: page);
      _pagination = response.pagination;
      
      // Reverse the list because API returns Oldest First, but we want Newest at index 0 for reverse ListView
      final List<MessageModel> newMessages = (response.data ?? []).reversed.toList();
      
      if (page == 1) {
        _messages = newMessages;
      } else {
        _messages.addAll(newMessages);
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching messages for $conversationId: $e');
      debugPrint('Stacktrace: $stackTrace');
    } finally {
      _isMessagesLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage({
    required String conversationId,
    required String messageType,
    String? text,
    String? mediaUrl,
    String? replyTo,
  }) async {
    try {
      final data = {
        'conversationId': conversationId,
        'messageType': messageType,
      };
      if (text != null) data['text'] = text;
      if (mediaUrl != null) data['mediaUrl'] = mediaUrl;
      
      // Use provided replyTo or the one in state
      final actualReplyTo = replyTo ?? _replyingToMessage?.sId;
      if (actualReplyTo != null) data['replyTo'] = actualReplyTo;

      final response = await _chatRepository.sendMessage(data);
      if (response['success'] == true) {
        clearReplyingMessage();
        // Optionally add message to local list instead of re-fetching
        // for better UX if it's not a real-time socket system
        await fetchMessages(conversationId);
        await fetchConversations();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  Future<bool> forwardMessage({
    required String recipientId,
    required MessageModel originalMessage,
  }) async {
    try {
      final data = {
        'recipientId': recipientId,
        'messageType': originalMessage.messageType ?? 'text',
        'text': originalMessage.text,
        'mediaUrl': originalMessage.mediaUrl,
        'isForwarded': true,
      };

      final response = await _chatRepository.sendMessage(data);
      if (response['success'] == true) {
        await fetchConversations();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error forwarding message: $e');
      return false;
    }
  }

  Future<void> editMessage(String conversationId, String messageId, String newText) async {
    try {
      await _chatRepository.editMessage(messageId, newText);
      final index = _messages.indexWhere((m) => m.sId == messageId);
      if (index != -1) {
        _messages[index].text = newText;
        _messages[index].isEdited = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error editing message: $e');
    }
  }

  Future<void> unsendMessage(String conversationId, String messageId) async {
    try {
      await _chatRepository.unsendMessage(messageId);
      final index = _messages.indexWhere((m) => m.sId == messageId);
      if (index != -1) {
        _messages[index].isUnsent = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error unsending message: $e');
    }
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await _chatRepository.deleteMessage(messageId);
      _messages.removeWhere((m) => m.sId == messageId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    try {
      final currentUserId = HiveService.userId;
      
      // Update locally for immediate feedback
      final index = _messages.indexWhere((m) => m.sId == messageId);
      if (index != -1) {
        final reactions = _messages[index].reactions ?? [];
        // Remove existing reaction from this user
        reactions.removeWhere((r) => r.userId == currentUserId);
        // Add new reaction
        reactions.add(ReactionModel(userId: currentUserId, emoji: emoji));
        _messages[index].reactions = reactions;
        notifyListeners();
      }

      await _chatRepository.reactToMessage(messageId, emoji);
    } catch (e) {
      debugPrint('Error reacting to message: $e');
    }
  }

  Future<String?> uploadAttachment(File file) async {
    try {
      final formData = dio.FormData.fromMap({
        'attachment': await dio.MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _chatRepository.uploadAttachment(formData);
      if (response['success'] == true) {
        return response['mediaUrl'] ?? response['url'] ?? response['data']?['url'];
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading attachment: $e');
      return null;
    }
  }

  Future<void> fetchUserStatus(String userId) async {
    try {
      final response = await _chatRepository.getUserStatus(userId);
      _currentUserStatus = response;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user status: $e');
    }
  }

  // User Search & Block
  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      _searchedUsers = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _chatRepository.searchUsers(query);
      _searchedUsers = response;
    } catch (e) {
      debugPrint('Error searching users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> blockUser(String userId) async {
    try {
      await _chatRepository.blockUser(userId);
      _blockedUserIds.add(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error blocking user: $e');
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      await _chatRepository.unblockUser(userId);
      _blockedUserIds.remove(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error unblocking user: $e');
    }
  }

  Future<void> fetchBlockedUsers() async {
    try {
      final response = await _chatRepository.getBlockedUsers();
      if (response['success'] == true) {
        _blockedUserIds = (response['data'] as List).map((e) => e['_id'] as String).toSet();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
    }
  }

  Future<List<MessageModel>> searchInMessages(String query, {String? conversationId}) async {
    try {
      final response = await _chatRepository.searchInMessages(query, conversationId: conversationId);
      return response;
    } catch (e) {
      debugPrint('Error searching in messages: $e');
      return [];
    }
  }
}
